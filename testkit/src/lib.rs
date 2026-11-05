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
    user_setting, AddExercisesRequest, AddLibraryTemplatesRequest, AdjustExerciseWeightRequest,
    AnswerRungRequest, AppendWorkoutHeartRateRequest, AppendWorkoutMutationsRequest,
    AppendWorkoutMutationsResponse, ApplyLibraryPlanRequest, CompleteOnboardingRequest,
    CompleteSetRequest, CompletedSet, DeleteCompletedSetRequest, DeleteTemplateRequest,
    DiscardWorkoutRequest, EditCompletedSetRequest, EndWorkoutRequest, Exercise, ExerciseWeight,
    GetHomeRequest, GetHomeResponse, GetWorkoutResponse, ImportHistory, ImportedWorkout,
    PlateColor, PlateColorsConfig, ProposedSet, RemoveExerciseRequest, ReorderExercisesRequest,
    ReorderTemplatesRequest, SaveTemplateRequest, SetOverrideRequest, SetWorkoutSessionRequest,
    SkipWarmupsRequest, StartSetRequest, StartWorkoutRequest, StartWorkoutResponse,
    UpdateSettingRequest, UserSetting, WeightUnit, WeightUnitConfig, Workout,
    WorkoutHeartRatePoint, WorkoutMutation, WorkoutTemplate,
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
    let state = GetWorkoutResponse {
        next_up_set: started.next_up_set,
        ..Default::default()
    };
    let (_, now) = train(store, lifter, &id, state, start + 120, MAX_SETS)?;
    end(store, lifter, id, start, now)?;
    Ok(now)
}

/// Up to `moves` of the lifter's moves in the workout under way, from
/// `now`: the workout as last answered, and the time after them.
fn train(
    store: &mut Store,
    lifter: &mut Lifter,
    id: &str,
    mut state: GetWorkoutResponse,
    mut now: i64,
    moves: usize,
) -> Result<(GetWorkoutResponse, i64)> {
    for _ in 0..moves {
        match lifter.next_move(id, &state) {
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
    Ok((state, now))
}

/// The watch's heart rate from `start`, then the end at `now`.
fn end(store: &mut Store, lifter: &mut Lifter, id: String, start: i64, now: i64) -> Result<()> {
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
    Ok(())
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

/// A write whose answer is not needed.
fn write<Req: Message>(store: &mut Store, method: &str, request: Req, now: i64) -> Result<()> {
    store
        .call(method, &request.encode_to_vec(), now)
        .map(|_| ())
}

/// A finished squat session from elsewhere ending at `end`, with its heart
/// rate, and a starting weight for the deadlift.
fn imported(end: i64) -> ImportHistory {
    let id = "imported-0".to_string();
    let mut workout = ImportedWorkout {
        workout: Some(Workout {
            id: id.clone(),
            name: "Imported".into(),
            start_time: end - 3_600,
            end_time: end,
            ..Default::default()
        }),
        ..Default::default()
    };
    for n in 0..3 {
        let set_id = format!("{id}:{n}");
        workout.proposed_sets.push(ProposedSet {
            id: set_id.clone(),
            workout_id: id.clone(),
            workout_order: n,
            exercise: Exercise::Squat as i32,
            target_reps: 5,
            target_weight: 135.0,
            rest_seconds: 180,
            ..Default::default()
        });
        workout.completed_sets.push(CompletedSet {
            id: format!("{set_id}:done"),
            workout_id: id.clone(),
            proposed_set_id: set_id,
            actual_reps: 5,
            actual_weight: 135.0,
            ended_at: end - 900 + i64::from(n) * 240,
            ..Default::default()
        });
    }
    workout.heart_rate = (0..30)
        .map(|n| WorkoutHeartRatePoint {
            sampled_at: (end - 1_800) * 1000 + n * 60_000,
            bpm: 110.0 + n as f32,
        })
        .collect();
    ImportHistory {
        workouts: vec![workout],
        starting_weights: vec![ExerciseWeight {
            exercise: Exercise::Deadlift as i32,
            weight_lb: 185.0,
        }],
    }
}

fn home(store: &mut Store, now: i64) -> Result<GetHomeResponse> {
    call(
        store,
        "GetHome",
        GetHomeRequest {
            budget_minutes: BUDGET_MINUTES,
        },
        now,
    )
}

fn save(store: &mut Store, template: WorkoutTemplate, unlink: bool, now: i64) -> Result<()> {
    write(
        store,
        "SaveTemplate",
        SaveTemplateRequest {
            template: Some(template),
            unlink,
        },
        now,
    )
}

fn setting(store: &mut Store, setting: user_setting::Setting, now: i64) -> Result<()> {
    write(
        store,
        "UpdateSetting",
        UpdateSettingRequest {
            setting: Some(UserSetting {
                setting: Some(setting),
            }),
        },
        now,
    )
}

/// Every other write the app makes, with fixed choices, around the
/// lifter's training from `start` (unix seconds): history imported, both
/// settings (the unit changed partway), an override, templates saved,
/// edited, made their own, reordered and deleted, a library entry and a
/// plan, a workout discarded, and in one workout warmups skipped, weights
/// moved, a done set edited and one undone, lifts added, removed and
/// reordered, and the session set. Returns when the last workout ended.
pub fn edits(store: &mut Store, lifter: &mut Lifter, start: i64) -> Result<i64> {
    const DAY: i64 = 86_400;
    write(store, "ImportHistory", imported(start - 3 * DAY), start)?;
    setting(
        store,
        user_setting::Setting::PlateColors(PlateColorsConfig {
            plates: vec![PlateColor {
                weight: 45.0,
                hex_color: "#1565C0".into(),
            }],
        }),
        start,
    )?;
    write(
        store,
        "SetOverride",
        SetOverrideRequest {
            exercise: Exercise::BenchPress as i32,
            weight: 115.0,
            reps: 6,
            sets: Some(4),
        },
        start,
    )?;

    // Their own template, a coupled one renamed, one made their own
    // unchanged; a library entry, then a plan as the rotation, then their
    // own order.
    let shown = home(store, start)?;
    save(
        store,
        WorkoutTemplate {
            name: "Arms".into(),
            exercises: vec![Exercise::BarbellCurl as i32, Exercise::SkullCrusher as i32],
            ..Default::default()
        },
        false,
        start,
    )?;
    let mut renamed = shown.templates[0].clone();
    renamed.name = format!("{} (mine)", renamed.name);
    save(store, renamed, false, start)?;
    save(store, shown.templates[1].clone(), true, start)?;
    write(
        store,
        "AddLibraryTemplates",
        AddLibraryTemplatesRequest {
            library_ids: vec!["push".into()],
            ..Default::default()
        },
        start,
    )?;
    write(
        store,
        "ApplyLibraryPlan",
        ApplyLibraryPlanRequest {
            plan_id: "upper_lower".into(),
        },
        start,
    )?;
    let mut order: Vec<String> = home(store, start)?
        .templates
        .iter()
        .map(|t| t.id.clone())
        .collect();
    order.reverse();
    write(
        store,
        "ReorderTemplates",
        ReorderTemplatesRequest {
            template_ids: order,
            rotation_count: Some(2),
        },
        start,
    )?;

    // A workout changed every way the app changes one.
    let begin = start + DAY;
    let started: StartWorkoutResponse = call(
        store,
        "StartWorkout",
        StartWorkoutRequest {
            exercises: vec![
                Exercise::Squat as i32,
                Exercise::BenchPress as i32,
                Exercise::BarbellRow as i32,
            ],
            budget_minutes: BUDGET_MINUTES,
            started_at: begin,
            ..Default::default()
        },
        begin,
    )?;
    let id = started.id;
    let mut now = begin + 120;
    let squat = Exercise::Squat as i32;
    mutate(
        store,
        Mutation::SkipWarmups(SkipWarmupsRequest {
            workout_id: id.clone(),
            exercise: squat,
        }),
        now,
    )?;
    let state = mutate(
        store,
        Mutation::AdjustExerciseWeight(AdjustExerciseWeightRequest {
            workout_id: id.clone(),
            exercise: squat,
            working_weight: 145.0,
            target_reps: 0,
        }),
        now,
    )?;
    let (state, later) = train(store, lifter, &id, state, now, 3)?;
    now = later;
    let first = state.completed_sets[0].clone();
    mutate(
        store,
        Mutation::EditCompletedSet(EditCompletedSetRequest {
            workout_id: id.clone(),
            completed_set_id: first.id,
            actual_reps: (first.actual_reps - 1).max(0),
            actual_weight: first.actual_weight,
        }),
        now,
    )?;
    let last = state.completed_sets[state.completed_sets.len() - 1].clone();
    mutate(
        store,
        Mutation::DeleteCompletedSet(DeleteCompletedSetRequest {
            workout_id: id.clone(),
            completed_set_id: last.id,
        }),
        now,
    )?;
    let raise = Exercise::LateralRaise as i32;
    mutate(
        store,
        Mutation::AddExercises(AddExercisesRequest {
            workout_id: id.clone(),
            exercises: vec![raise, Exercise::DumbbellCurl as i32],
            ..Default::default()
        }),
        now,
    )?;
    mutate(
        store,
        Mutation::AdjustExerciseWeight(AdjustExerciseWeightRequest {
            workout_id: id.clone(),
            exercise: Exercise::DumbbellCurl as i32,
            working_weight: 25.0,
            target_reps: 12,
        }),
        now,
    )?;
    mutate(
        store,
        Mutation::RemoveExercise(RemoveExerciseRequest {
            workout_id: id.clone(),
            exercise: Exercise::BarbellRow as i32,
        }),
        now,
    )?;
    mutate(
        store,
        Mutation::ReorderExercises(ReorderExercisesRequest {
            workout_id: id.clone(),
            exercises: vec![raise, squat],
        }),
        now,
    )?;
    let state = mutate(
        store,
        Mutation::SetSession(SetWorkoutSessionRequest {
            workout_id: id.clone(),
            session_id: "session-golden".into(),
        }),
        now,
    )?;
    let (_, now) = train(store, lifter, &id, state, now, MAX_SETS)?;
    end(store, lifter, id, begin, now)?;

    // The unit changes; a workout is started and thrown away; one more in
    // the new unit; the template of their own is deleted.
    setting(
        store,
        user_setting::Setting::WeightUnit(WeightUnitConfig {
            unit: WeightUnit::Kg as i32,
        }),
        now + DAY,
    )?;
    let begin = now + 2 * DAY;
    let thrown: StartWorkoutResponse = call(
        store,
        "StartWorkout",
        StartWorkoutRequest {
            exercises: vec![Exercise::Deadlift as i32],
            started_at: begin,
            ..Default::default()
        },
        begin,
    )?;
    write(
        store,
        "DiscardWorkout",
        DiscardWorkoutRequest {
            workout_id: thrown.id,
        },
        begin + 60,
    )?;
    let ended = workout(store, lifter, begin + 600)?;
    let arms = home(store, ended)?
        .templates
        .into_iter()
        .find(|t| t.name == "Arms")
        .ok_or("Arms was saved")?;
    write(
        store,
        "DeleteTemplate",
        DeleteTemplateRequest {
            template_id: arms.id,
        },
        ended,
    )?;
    Ok(ended)
}
