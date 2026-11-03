//! A seeded lifter that trains as a person does, through the phone's own
//! store: home's suggestion, each set started and done (a rep short now and
//! then), the calibration ramp's question answered, heart rate from the
//! watch, the workout ended. The same seed makes the same choices, so a
//! history is reproducible; it is what a phone would have recorded.
//!
//! Used by the load test (clients that train live, or restore a history
//! before they start) and by the golden history test.

use prost::Message;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use schlift_core::pb::workout_mutation::Mutation;
use schlift_core::pb::{
    AnswerRungRequest, AppendWorkoutHeartRateRequest, AppendWorkoutMutationsRequest,
    AppendWorkoutMutationsResponse, CompleteOnboardingRequest, CompleteSetRequest,
    EndWorkoutRequest, GetHomeRequest, GetHomeResponse, GetWorkoutResponse, StartSetRequest,
    StartWorkoutRequest, StartWorkoutResponse, WorkoutHeartRatePoint, WorkoutMutation,
};
use schlift_native::store::Store;

/// The workout budget the lifter asks home for.
pub const BUDGET_MINUTES: i32 = 45;
/// A workout ends here at the latest, whatever the plan.
const MAX_SETS: usize = 40;
/// How long a set takes to lift, seconds.
const SET_SECONDS: i64 = 40;
/// The watch's heart-rate reading, every this many ms.
const HEART_RATE_EVERY_MS: i64 = 2_000;

type Result<T> = std::result::Result<T, String>;

/// One person's habits, from a seed.
pub struct Lifter {
    rng: StdRng,
}

/// What the lifter does next in a workout under way.
pub enum Move {
    /// The ramp asked how many more reps were left.
    AnswerRung(AnswerRungRequest),
    /// The up-next set, started then done.
    Lift(StartSetRequest, CompleteSetRequest),
    /// Nothing left: end it.
    End,
}

impl Lifter {
    pub fn new(seed: u64) -> Self {
        Self {
            rng: StdRng::seed_from_u64(seed),
        }
    }

    /// The next move, given the workout as the core answered it last.
    pub fn next_move(&mut self, workout_id: &str, state: &GetWorkoutResponse) -> Move {
        if !state.rung_question_set_id.is_empty() {
            return Move::AnswerRung(AnswerRungRequest {
                workout_id: workout_id.to_string(),
                proposed_set_id: state.rung_question_set_id.clone(),
                reps_left: self.rng.gen_range(1..=3),
                jump_lb: 0.0,
            });
        }
        let Some(set) = &state.next_up_set else {
            return Move::End;
        };
        let missed = i32::from(self.rng.gen_bool(0.15));
        Move::Lift(
            StartSetRequest {
                workout_id: workout_id.to_string(),
                proposed_set_id: set.id.clone(),
                started_at: 0,
            },
            CompleteSetRequest {
                workout_id: workout_id.to_string(),
                proposed_set_id: set.id.clone(),
                actual_reps: (set.target_reps - missed).max(0),
                actual_weight: set.target_weight,
                completed_at: 0,
            },
        )
    }

    /// The watch's readings from `from_ms` to `to_ms`: one every couple of
    /// seconds, climbing through a set and falling through the rest.
    pub fn heart_rate(&mut self, from_ms: i64, to_ms: i64) -> Vec<WorkoutHeartRatePoint> {
        let mut at = from_ms;
        let mut samples = Vec::new();
        while at <= to_ms {
            let phase = ((at - from_ms) % 180_000) as f32 / 180_000.0;
            let shape = if phase < 0.3 {
                phase / 0.3
            } else {
                1.0 - (phase - 0.3) / 0.7
            };
            let bpm = 100.0 + 50.0 * shape + self.rng.gen_range(-4.0..4.0);
            samples.push(WorkoutHeartRatePoint {
                sampled_at: at,
                bpm: bpm.round(),
            });
            at += HEART_RATE_EVERY_MS + self.rng.gen_range(-300..300);
        }
        samples
    }
}

fn call<Req: Message, Resp: Message + Default>(
    store: &mut Store,
    method: &str,
    request: Req,
    now: i64,
) -> Result<Resp> {
    let answer = store.call(method, &request.encode_to_vec(), now)?;
    Resp::decode(answer.as_slice()).map_err(|e| e.to_string())
}

fn mutate(store: &mut Store, mutation: Mutation, now: i64) -> Result<GetWorkoutResponse> {
    let response: AppendWorkoutMutationsResponse = call(
        store,
        "AppendWorkoutMutations",
        AppendWorkoutMutationsRequest {
            mutations: vec![WorkoutMutation {
                mutation: Some(mutation),
            }],
        },
        now,
    )?;
    Ok(response.workout_state.unwrap_or_default())
}

/// Sign-up's choices, the defaults: the unit, the default library
/// templates, starting weights from the middle of the strength slider.
pub fn onboard(store: &mut Store, now: i64) -> Result<()> {
    call::<_, schlift_core::pb::CompleteOnboardingResponse>(
        store,
        "CompleteOnboarding",
        CompleteOnboardingRequest {
            strength: Some(0.3),
            ..Default::default()
        },
        now,
    )?;
    Ok(())
}

/// One whole workout from `start` (unix seconds), at the times a person
/// would do it: a set every rest, heart rate throughout, ended when the plan
/// runs out. Returns when it ended.
pub fn workout(store: &mut Store, lifter: &mut Lifter, start: i64) -> Result<i64> {
    let home: GetHomeResponse = call(
        store,
        "GetHome",
        GetHomeRequest {
            budget_minutes: BUDGET_MINUTES,
        },
        start,
    )?;
    let template_id = match home.suggested_template_id.as_str() {
        "" => home
            .templates
            .first()
            .map(|t| t.id.clone())
            .unwrap_or_default(),
        id => id.to_string(),
    };
    let started: StartWorkoutResponse = call(
        store,
        "StartWorkout",
        StartWorkoutRequest {
            template_id,
            budget_minutes: BUDGET_MINUTES,
            started_at: start,
            ..Default::default()
        },
        start,
    )?;
    let id = started.id;
    let mut state = GetWorkoutResponse {
        next_up_set: started.next_up_set,
        ..Default::default()
    };
    let mut now = start + 120;
    for _ in 0..MAX_SETS {
        match lifter.next_move(&id, &state) {
            Move::AnswerRung(answer) => {
                state = mutate(store, Mutation::AnswerRung(answer), now)?;
            }
            Move::Lift(mut begin, mut done) => {
                let rest = state
                    .next_up_set
                    .as_ref()
                    .map_or(90, |s| i64::from(s.rest_seconds.max(30)));
                begin.started_at = now;
                mutate(store, Mutation::StartSet(begin), now)?;
                now += SET_SECONDS;
                done.completed_at = now;
                state = mutate(store, Mutation::CompleteSet(done), now)?;
                now += rest;
            }
            Move::End => break,
        }
    }
    let _: schlift_core::pb::AppendWorkoutHeartRateResponse = call(
        store,
        "AppendWorkoutHeartRate",
        AppendWorkoutHeartRateRequest {
            workout_id: id.clone(),
            samples: lifter.heart_rate(start * 1000, now * 1000),
        },
        now,
    )?;
    let _: schlift_core::pb::EndWorkoutResponse = call(
        store,
        "EndWorkout",
        EndWorkoutRequest {
            workout_id: id,
            ended_at: now,
        },
        now,
    )?;
    Ok(now)
}

/// `weeks` of training ending before `until` (unix seconds): `per_week`
/// workouts a week, early evenings, as an onboarded lifter. Returns how many.
pub fn history(
    store: &mut Store,
    lifter: &mut Lifter,
    weeks: u32,
    per_week: u32,
    until: i64,
) -> Result<usize> {
    const DAY: i64 = 86_400;
    let first = until - i64::from(weeks) * 7 * DAY;
    let mut done = 0;
    for week in 0..i64::from(weeks) {
        for n in 0..i64::from(per_week) {
            let day = first + week * 7 * DAY + n * 7 * DAY / i64::from(per_week.max(1));
            let start = day - day % DAY + 18 * 3_600 + lifter.rng.gen_range(0..3_600);
            if start >= until {
                return Ok(done);
            }
            workout(store, lifter, start)?;
            done += 1;
        }
    }
    Ok(done)
}
