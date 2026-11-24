//! Phones training, for `schlift-population --train`: each an account
//! `seed-population` wrote, already signed in and synced, its app open. At
//! a random moment it starts the workout home suggests and does it as a
//! person does (schlift_testkit's lifter): a set started, done half a minute
//! to a minute later, then the plan's rest (give or take a third) before the
//! next, the ramp's questions answered as they come, ended when the plan
//! runs out. Every write goes through the phone's own core (`Call`, as the
//! app's store makes it) and its events go up the Sync stream at once, as
//! the app pushes them; each is timed until the server sends it back placed
//! (its ack, with the next flush).

use std::collections::HashMap;
use std::time::Instant;

use prost::Message;
use rand::rngs::StdRng;
use rand::Rng;
use schlift_core::account::Account;
use schlift_core::api::{self, Call};
use schlift_core::events::Event;
use schlift_core::pb::workout_mutation::Mutation;
use schlift_core::pb::*;
use schlift_testkit::{Lifter, Move, BUDGET_MINUTES};

/// Where a phone is in its workout.
enum Step {
    /// Not started; starts at the next action.
    Waiting,
    /// Under way: the workout as the core last answered it.
    Training(String, GetWorkoutResponse),
    /// A set started: done at the next action.
    Lifting(String, CompleteSetRequest),
    Done,
}

/// One phone's app: its account and the person using it.
pub struct Phone {
    account: Account,
    lifter: Lifter,
    step: Step,
    /// Pushed, not yet heard back placed: when each went up.
    pub unacked: HashMap<String, Instant>,
}

/// What a phone did at an action: the events to push, and what it was.
pub struct Done {
    pub events: Vec<Event>,
    pub what: &'static str,
    /// Seconds until its next action; None once the workout is over.
    pub next_in: Option<f64>,
}

fn event_id(rng: &mut StdRng) -> String {
    let v: u128 = rng.gen();
    let h = format!("{v:032x}");
    format!(
        "{}-{}-4{}-a{}-{}",
        &h[..8],
        &h[8..12],
        &h[13..16],
        &h[17..20],
        &h[20..32]
    )
}

impl Phone {
    pub fn new(account: Account, seed: u64) -> Self {
        Self {
            account,
            lifter: Lifter::new(seed),
            step: Step::Waiting,
            unacked: HashMap::new(),
        }
    }

    /// One call through the core, as the app's store makes it: the answer,
    /// and the events it recorded.
    fn call<Req: Message, Resp: Message + Default>(
        &mut self,
        rng: &mut StdRng,
        method: &str,
        request: Req,
        now: i64,
    ) -> Result<(Resp, Vec<Event>), String> {
        let mut call = Call::new(&mut self.account, now, event_id(rng));
        let answer =
            api::call(&mut call, method, &request.encode_to_vec()).map_err(|e| e.to_string())?;
        let events = std::mem::take(&mut call.events);
        Ok((
            Resp::decode(answer.as_slice()).map_err(|e| e.to_string())?,
            events,
        ))
    }

    fn mutate(
        &mut self,
        rng: &mut StdRng,
        mutation: Mutation,
        now: i64,
    ) -> Result<(GetWorkoutResponse, Vec<Event>), String> {
        let (response, events): (AppendWorkoutMutationsResponse, _) = self.call(
            rng,
            "AppendWorkoutMutations",
            AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    mutation: Some(mutation),
                }],
            },
            now,
        )?;
        Ok((response.workout_state.unwrap_or_default(), events))
    }

    /// The person's next action, at `now` (Unix seconds).
    pub fn act(&mut self, rng: &mut StdRng, now: i64) -> Result<Done, String> {
        match std::mem::replace(&mut self.step, Step::Done) {
            Step::Waiting => {
                let (home, _): (GetHomeResponse, _) = self.call(
                    rng,
                    "GetHome",
                    GetHomeRequest {
                        budget_minutes: BUDGET_MINUTES,
                    },
                    now,
                )?;
                let template_id = match home.suggested_template_id.as_str() {
                    "" => home
                        .templates
                        .first()
                        .map(|t| t.id.clone())
                        .unwrap_or_default(),
                    id => id.to_string(),
                };
                let (started, events): (StartWorkoutResponse, _) = self.call(
                    rng,
                    "StartWorkout",
                    StartWorkoutRequest {
                        template_id,
                        budget_minutes: BUDGET_MINUTES,
                        started_at: now,
                        ..Default::default()
                    },
                    now,
                )?;
                let state = GetWorkoutResponse {
                    next_up_set: started.next_up_set,
                    ..Default::default()
                };
                self.step = Step::Training(started.id, state);
                // Setting up the first lift.
                Ok(Done {
                    events,
                    what: "start",
                    next_in: Some(rng.gen_range(30.0..120.0)),
                })
            }
            Step::Training(id, state) => match self.lifter.next_move(&id, &state) {
                Move::AnswerRung(answer) => {
                    let (state, events) = self.mutate(rng, Mutation::AnswerRung(answer), now)?;
                    self.step = Step::Training(id, state);
                    Ok(Done {
                        events,
                        what: "answer",
                        next_in: Some(rng.gen_range(2.0..8.0)),
                    })
                }
                Move::AnswerEffort(answer) => {
                    let (state, events) = self.mutate(rng, Mutation::AnswerEffort(answer), now)?;
                    self.step = Step::Training(id, state);
                    Ok(Done {
                        events,
                        what: "answer",
                        next_in: Some(rng.gen_range(2.0..8.0)),
                    })
                }
                Move::Lift(mut begin, done) => {
                    begin.started_at = now;
                    let (_, events) = self.mutate(rng, Mutation::StartSet(begin), now)?;
                    self.step = Step::Lifting(id, done);
                    // A set takes half a minute to a minute.
                    Ok(Done {
                        events,
                        what: "set started",
                        next_in: Some(rng.gen_range(30.0..60.0)),
                    })
                }
                Move::End => {
                    let (_, events): (EndWorkoutResponse, _) = self.call(
                        rng,
                        "EndWorkout",
                        EndWorkoutRequest {
                            workout_id: id,
                            ended_at: now,
                        },
                        now,
                    )?;
                    Ok(Done {
                        events,
                        what: "end",
                        next_in: None,
                    })
                }
            },
            Step::Lifting(id, mut done) => {
                done.completed_at = now;
                let (state, events) = self.mutate(rng, Mutation::CompleteSet(done), now)?;
                // The plan's rest, give or take a third (at least half a minute).
                let rest = state
                    .next_up_set
                    .as_ref()
                    .map_or(90, |s| s.rest_seconds.max(30)) as f64;
                self.step = Step::Training(id, state);
                Ok(Done {
                    events,
                    what: "set done",
                    next_in: Some(rest * rng.gen_range(0.67..1.33)),
                })
            }
            Step::Done => Ok(Done {
                events: Vec::new(),
                what: "done",
                next_in: None,
            }),
        }
    }
}
