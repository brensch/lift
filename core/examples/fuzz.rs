//! Drives the core through randomised but realistic workout sessions and
//! asserts invariants after every mutation.
//!
//! This exists to find the bugs unit tests do not: ones that need a specific
//! *sequence* of operations (edit a plan mid-set, delete a completed set, skip
//! warmups, reorder groups, rate or re-rate a set, edit a done set,
//! end twice).
//!
//! It runs the core in-process, as the phone does, and after every user also
//! checks that replaying their recorded events rebuilds the same account.
//!
//! ```text
//! cargo run --release -p schlift-core --example fuzz -- --users 8 --sessions 12
//! make fuzz-api
//! ```
//!
//! Exit code is non-zero if any invariant is violated, so it can gate CI.

use std::collections::{HashMap, HashSet};

use clap::Parser;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use schlift_core::account::Account;
use schlift_core::api::{Call, View};
use schlift_core::pb::{
    workout_mutation::Mutation, AddExercisesRequest, AdjustExerciseWeightRequest,
    AppendWorkoutMutationsRequest, CompleteOnboardingRequest, CompleteSetRequest, CompletedSet,
    DeleteCompletedSetRequest, EditCompletedSetRequest, Effort, EndWorkoutRequest, Event, Exercise,
    ExperienceLevel, GetWorkoutRequest, GetWorkoutResponse, RateExerciseRequest,
    RemoveExerciseRequest, ReorderExercisesRequest, SkipWarmupsRequest, StartSetRequest,
    StartWorkoutRequest, WeightUnit, WorkoutMutation, WorkoutState,
};

#[derive(Parser, Debug)]
#[command(about = "Randomised API sequence fuzzer with invariant checks")]
struct Args {
    /// Simulated users, run concurrently.
    #[arg(long, default_value_t = 6)]
    users: usize,
    /// Workouts per user.
    #[arg(long, default_value_t = 10)]
    sessions: usize,
    /// Seed for reproducibility — a failure prints the seed to replay it.
    #[arg(long, default_value_t = 0xC0FFEE)]
    seed: u64,
}

/// A violated invariant, with enough context to reproduce it.
#[derive(Debug)]
struct Violation {
    user: String,
    workout_id: String,
    step: String,
    invariant: &'static str,
    detail: String,
}

/// One user's phone, minus storage: the account and its event log.
struct Sim {
    account: Account,
    log: Vec<Event>,
    next_id: u64,
    user: usize,
}

impl Sim {
    fn view(&self, now: i64) -> View<'_> {
        View::new(&self.account, now)
    }

    fn call(&mut self, now: i64) -> Recording<'_> {
        self.next_id += 1;
        Recording {
            call: Call::new(
                &mut self.account,
                now,
                format!("fuzz-{}-{}", self.user, self.next_id),
            ),
            log: &mut self.log,
        }
    }
}

/// A call whose events land in the log when it's done.
struct Recording<'a> {
    call: Call<'a>,
    log: &'a mut Vec<Event>,
}

impl<'a> std::ops::Deref for Recording<'a> {
    type Target = Call<'a>;
    fn deref(&self) -> &Self::Target {
        &self.call
    }
}

impl std::ops::DerefMut for Recording<'_> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.call
    }
}

impl Drop for Recording<'_> {
    fn drop(&mut self) {
        self.log.append(&mut self.call.events);
    }
}

/// One simulated user: a series of workouts, with invariants checked after every
/// mutation. Returns the violations it found and how many mutations it made.
fn run_user(seed: u64, user_idx: usize, sessions: usize) -> (Vec<Violation>, usize) {
    // Decorrelate each user's stream so they do not all make the same choices.
    let mut rng = StdRng::seed_from_u64(seed ^ ((user_idx as u64 + 1) << 32));
    let mut violations: Vec<Violation> = Vec::new();
    let mut steps = 0usize;
    let username = format!("fuzz-user-{seed}-{user_idx}");
    let mut sim = Sim {
        account: Account::default(),
        log: Vec::new(),
        next_id: 0,
        user: user_idx,
    };
    let now = 1_700_000_000;

    // Onboard as the app does: seeds the default templates and trackers.
    let templates = match sim
        .call(now)
        .complete_onboarding(CompleteOnboardingRequest {
            body_weight_kg: if rng.gen_bool(0.5) {
                rng.gen_range(50..120) as f32
            } else {
                0.0
            },
            experience: ExperienceLevel::Beginner as i32,
            unit: if rng.gen_bool(0.3) {
                WeightUnit::Kg as i32
            } else {
                WeightUnit::Lb as i32
            },
            gender: rng.gen_range(0..3),
            library_ids: vec![],
            strength: None,
        }) {
        Ok(r) => r.home.map(|h| h.templates).unwrap_or_default(),
        Err(e) => {
            violations.push(Violation {
                user: username.clone(),
                workout_id: String::new(),
                step: "complete_onboarding".into(),
                invariant: "CompleteOnboarding returned an error",
                detail: e.to_string(),
            });
            Vec::new()
        }
    };

    for session_idx in 0..sessions {
        // Sometimes far in the future so the layoff deload path is exercised.
        let at_time = 1_700_000_000
            + (session_idx as i64) * 2 * 86_400
            + if rng.gen_bool(0.15) {
                rng.gen_range(15..70) * 86_400
            } else {
                0
            };

        // Half the sessions start from a template (the app's main path);
        // the rest send explicit exercises (the "empty workout" path).
        let request = if !templates.is_empty() && rng.gen_bool(0.5) {
            let template = &templates[rng.gen_range(0..templates.len())];
            StartWorkoutRequest {
                name: String::new(),
                exercises: vec![],
                started_at: at_time,
                template_id: template.id.clone(),
            }
        } else {
            let exercise_count = rng.gen_range(1..4);
            StartWorkoutRequest {
                name: format!("Fuzz {session_idx}"),
                exercises: (0..exercise_count)
                    .map(|_| random_exercise(&mut rng) as i32)
                    .collect(),
                started_at: at_time,
                template_id: String::new(),
            }
        };

        let started = match sim.call(now).start_workout(request) {
            Ok(r) => r,
            Err(e) => {
                violations.push(Violation {
                    user: username.clone(),
                    workout_id: String::new(),
                    step: "start_workout".into(),
                    invariant: "StartWorkout returned an error",
                    detail: e.to_string(),
                });
                continue;
            }
        };
        let workout_id = started.workout.as_ref().unwrap().id.clone();

        let mut now = at_time + 60;
        let mut ops = rng.gen_range(6..26);

        while ops > 0 {
            ops -= 1;
            steps += 1;

            let state = match sim.view(now).get_workout(GetWorkoutRequest {
                workout_id: workout_id.clone(),
            }) {
                Ok(r) => r,
                Err(e) => {
                    violations.push(Violation {
                        user: username.clone(),
                        workout_id: workout_id.clone(),
                        step: "get_workout".into(),
                        invariant: "GetWorkout returned an error",
                        detail: e.to_string(),
                    });
                    break;
                }
            };

            let pending: Vec<_> = state
                .proposed_sets
                .iter()
                .filter(|s| {
                    !s.cancelled
                        && !state
                            .completed_sets
                            .iter()
                            .any(|c| c.proposed_set_id == s.id)
                })
                .cloned()
                .collect();

            let done: Vec<CompletedSet> = state
                .completed_sets
                .iter()
                .filter(|c| c.ended_at != 0)
                .cloned()
                .collect();

            let action = rng.gen_range(0..100);
            let step_name;
            // What a mutation promised, checked against the state after it.
            let mut expect: Option<Expectation> = None;

            if pending.is_empty() && action < 60 {
                break;
            } else if action < 38 && !pending.is_empty() {
                // Complete a set: usually the one Done points at (which may
                // be a rung's would-be `{done_id}:0`, not yet in the plan),
                // sometimes any pending set out of order.
                let set = match state.next_up_set.as_ref() {
                    Some(next) if rng.gen_bool(0.6) => next,
                    _ => &pending[rng.gen_range(0..pending.len())],
                };
                // Usually Start first (the app's flow); sometimes only Start,
                // leaving the set lifting for whatever comes next; sometimes
                // a Done with no Start (a watch Done), with or without a
                // rating.
                let started = rng.gen_bool(0.7);
                if started {
                    now += 20;
                    let _ = sim
                        .call(now)
                        .append_workout_mutations(AppendWorkoutMutationsRequest {
                            mutations: vec![mutation_at(
                                Mutation::StartSet(StartSetRequest {
                                    workout_id: workout_id.clone(),
                                    proposed_set_id: set.id.clone(),
                                    started_at: now,
                                }),
                                now,
                            )],
                        });
                }
                if started && rng.gen_bool(0.2) {
                    step_name = format!("start_set({})", set.id);
                } else {
                    let effort = if rng.gen_bool(0.5) {
                        [Effort::Easy, Effort::Right, Effort::Hard][rng.gen_range(0..3)] as i32
                    } else {
                        0
                    };
                    step_name = format!("complete_set({}, effort {effort})", set.id);
                    now += 45;
                    let _ = sim.call(now).complete_set(CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: set.id.clone(),
                        actual_reps: rng.gen_range(0..12),
                        actual_weight: set.target_weight,
                        completed_at: now,
                        effort,
                    });
                    now += 90;
                }
            } else if action < 43 && pending.iter().any(|p| p.warmup) {
                // Skip all of an exercise's warmups: they're marked, never
                // removed.
                let warm: Vec<_> = pending.iter().filter(|p| p.warmup).collect();
                let exercise = warm[rng.gen_range(0..warm.len())].exercise;
                step_name = format!("skip_warmups({exercise})");
                let _ = sim
                    .call(now)
                    .append_workout_mutations(AppendWorkoutMutationsRequest {
                        mutations: vec![mutation_at(
                            Mutation::SkipWarmups(SkipWarmupsRequest {
                                workout_id: workout_id.clone(),
                                exercise,
                            }),
                            now,
                        )],
                    });
            } else if action < 46 && !pending.is_empty() {
                // Any set, in any order: warmups are never removed, a
                // working set just moves past them.
                let set = &pending[rng.gen_range(0..pending.len())];
                step_name = format!("complete_set_out_of_order({})", set.id);
                let _ = sim.call(now).complete_set(CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: set.target_reps,
                    actual_weight: set.target_weight,
                    completed_at: now,
                    effort: 0,
                });
                now += 90;
            } else if action < 54 && !state.completed_sets.is_empty() {
                // Undo a completed set.
                let c = &state.completed_sets[rng.gen_range(0..state.completed_sets.len())];
                step_name = format!("delete_completed_set({})", c.id);
                let _ = sim
                    .call(now)
                    .delete_completed_set(DeleteCompletedSetRequest {
                        workout_id: workout_id.clone(),
                        completed_set_id: c.id.clone(),
                    });
            } else if action < 62 && !state.proposed_sets.is_empty() {
                // Adjust a weight mid-workout, as the app does.
                let s = &state.proposed_sets[rng.gen_range(0..state.proposed_sets.len())];
                let weight = (rng.gen_range(9..60) * 5) as f32;
                step_name = format!("adjust_weight({})", s.exercise);
                let _ = sim
                    .call(now)
                    .adjust_exercise_weight(AdjustExerciseWeightRequest {
                        workout_id: workout_id.clone(),
                        exercise: s.exercise,
                        working_weight: weight,
                        target_reps: 0,
                    });
            } else if action < 70 {
                // Add or remove an exercise mid-workout.
                if rng.gen_bool(0.5) || state.proposed_sets.is_empty() {
                    let exercise = random_exercise(&mut rng) as i32;
                    step_name = format!("add_exercises({exercise})");
                    let _ = sim.call(now).add_exercises(AddExercisesRequest {
                        workout_id: workout_id.clone(),
                        exercises: vec![exercise],
                    });
                } else {
                    let s = &state.proposed_sets[rng.gen_range(0..state.proposed_sets.len())];
                    step_name = format!("remove_exercise({})", s.exercise);
                    let _ = sim.call(now).remove_exercise(RemoveExerciseRequest {
                        workout_id: workout_id.clone(),
                        exercise: s.exercise,
                    });
                }
            } else if action < 76 && !state.proposed_sets.is_empty() {
                // Reorder the exercise blocks.
                let mut exercises: Vec<i32> = Vec::new();
                for s in &state.proposed_sets {
                    if !exercises.contains(&s.exercise) {
                        exercises.push(s.exercise);
                    }
                }
                for i in (1..exercises.len()).rev() {
                    exercises.swap(i, rng.gen_range(0..=i));
                }
                step_name = "reorder_exercises".to_string();
                let _ = sim.call(now).reorder_exercises(ReorderExercisesRequest {
                    workout_id: workout_id.clone(),
                    exercises,
                });
            } else if action < 88 && !done.is_empty() {
                // Answer, or change the answer, for a done set. Usually the
                // latest (what the chips target); sometimes an older set
                // or a warmup, which must change nothing. Time plays no
                // part: the clock resolves nothing.
                let latest = done.iter().max_by_key(|c| c.ended_at).cloned().unwrap();
                let c = if rng.gen_bool(0.7) {
                    latest.clone()
                } else {
                    done[rng.gen_range(0..done.len())].clone()
                };
                let effort = [Effort::Easy, Effort::Right, Effort::Hard][rng.gen_range(0..3)];
                let lands = c.id == latest.id && prompt_worthy(&state, &c);
                step_name = format!("rate_exercise({}, {effort:?})", c.id);
                expect = Some(if lands {
                    Expectation::Rated {
                        completed_set_id: c.id.clone(),
                        effort,
                    }
                } else {
                    Expectation::RateNoop {
                        completed_set_id: c.id.clone(),
                        effort_before: c.effort,
                        proposed_before: state.proposed_sets.len(),
                    }
                });
                let _ = sim
                    .call(now)
                    .append_workout_mutations(AppendWorkoutMutationsRequest {
                        mutations: vec![mutation_at(
                            Mutation::RateExercise(RateExerciseRequest {
                                workout_id: workout_id.clone(),
                                completed_set_id: c.id.clone(),
                                effort: effort as i32,
                            }),
                            now,
                        )],
                    });
            } else if !done.is_empty() {
                // Correct a done set after the fact.
                let c = &done[rng.gen_range(0..done.len())];
                let reps = rng.gen_range(0..12);
                let weight = if rng.gen_bool(0.3) {
                    (rng.gen_range(9..60) * 5) as f32
                } else {
                    c.actual_weight
                };
                step_name = format!("edit_completed_set({})", c.id);
                expect = Some(Expectation::Edited {
                    completed_set_id: c.id.clone(),
                    reps,
                    weight,
                });
                let _ = sim
                    .call(now)
                    .append_workout_mutations(AppendWorkoutMutationsRequest {
                        mutations: vec![mutation_at(
                            Mutation::EditCompletedSet(EditCompletedSetRequest {
                                workout_id: workout_id.clone(),
                                completed_set_id: c.id.clone(),
                                actual_reps: reps,
                                actual_weight: weight,
                            }),
                            now,
                        )],
                    });
            } else {
                continue;
            }

            if let Ok(after) = sim.view(now).get_workout(GetWorkoutRequest {
                workout_id: workout_id.clone(),
            }) {
                check_invariants(&after, &username, &step_name, &mut violations);
                if let Some(expectation) = expect {
                    check_expectation(&after, &expectation, &username, &step_name, &mut violations);
                }
            }
        }

        // End the workout, sometimes twice — EndWorkout must be idempotent,
        // and a re-fire must not advance a tracker a second time.
        let _ = sim.call(now).end_workout(EndWorkoutRequest {
            workout_id: workout_id.clone(),
            ended_at: now,
        });
        if rng.gen_bool(0.25) {
            let before: HashMap<i32, (f32, i32)> = home_trackers(sim.view(now));
            let _ = sim.call(now).end_workout(EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ended_at: now,
            });
            let after = home_trackers(sim.view(now));
            for (exercise, (weight, reps)) in &before {
                if let Some((weight_after, reps_after)) = after.get(exercise) {
                    if (weight_after - weight).abs() > 0.01 || reps_after != reps {
                        violations.push(Violation {
                            user: username.clone(),
                            workout_id: workout_id.clone(),
                            step: "end_workout(again)".into(),
                            invariant: "a re-fired EndWorkout moved a tracker",
                            detail: format!(
                                "exercise {exercise}: {weight}@{reps} -> {weight_after}@{reps_after}"
                            ),
                        });
                    }
                }
            }
        }

        // No question survives EndWorkout: every done set that asked has
        // an answer, "right" by default.
        if let Ok(ended) = sim.view(now).get_workout(GetWorkoutRequest {
            workout_id: workout_id.clone(),
        }) {
            for c in ended.completed_sets.iter().filter(|c| c.ended_at != 0) {
                if prompt_worthy(&ended, c) && c.effort == Effort::Unspecified as i32 {
                    violations.push(Violation {
                        user: username.clone(),
                        workout_id: workout_id.clone(),
                        step: "end_workout".into(),
                        invariant: "an effort prompt was left pending after EndWorkout",
                        detail: format!("completed set {} has no effort", c.id),
                    });
                }
            }
        }

        // After ending, there must be no active workout left behind.
        {
            let active = sim.view(now).get_active_workout();
            if let Some(w) = active.workout.as_ref() {
                if w.id == workout_id {
                    violations.push(Violation {
                        user: username.clone(),
                        workout_id: workout_id.clone(),
                        step: "end_workout".into(),
                        invariant: "workout is still active after EndWorkout",
                        detail: format!("GetActiveWorkout still returns {}", w.id),
                    });
                }
            }
        }
    }

    // The log is the account: replaying it rebuilds exactly what the calls
    // left behind.
    if Account::fold(&sim.log) != sim.account {
        violations.push(Violation {
            user: username.clone(),
            workout_id: String::new(),
            step: "replay".into(),
            invariant: "replaying the event log did not rebuild the account",
            detail: format!("{} events", sim.log.len()),
        });
    }

    (violations, steps)
}

/// (exercise -> (working weight, target reps)) from the home.
fn home_trackers(view: View) -> HashMap<i32, (f32, i32)> {
    view.get_home()
        .trackers
        .into_iter()
        .map(|t| (t.exercise, (t.working_weight, t.target_reps)))
        .collect()
}

fn mutation_at(mutation: Mutation, at: i64) -> WorkoutMutation {
    WorkoutMutation {
        event_id: uuid::Uuid::new_v4().to_string(),
        client_created_at: at,
        mutation: Some(mutation),
    }
}

/// Client-side mirror of the reducer's prompt rule: every working set and
/// every calibration rung asks "how was that"; warmups never do.
fn prompt_worthy(state: &GetWorkoutResponse, done: &CompletedSet) -> bool {
    state
        .proposed_sets
        .iter()
        .find(|p| p.id == done.proposed_set_id && !p.cancelled)
        .is_some_and(|p| p.calibration || !p.warmup)
}

/// What one of the new mutations promised about the state after it.
enum Expectation {
    /// The latest done set, prompt-worthy: it carries the new answer.
    Rated {
        completed_set_id: String,
        effort: Effort,
    },
    /// Not the latest done set, or a warmup: nothing changes.
    RateNoop {
        completed_set_id: String,
        effort_before: i32,
        proposed_before: usize,
    },
    Edited {
        completed_set_id: String,
        reps: i32,
        weight: f32,
    },
}

fn check_expectation(
    state: &GetWorkoutResponse,
    expectation: &Expectation,
    user: &str,
    step: &str,
    out: &mut Vec<Violation>,
) {
    let workout_id = state
        .workout
        .as_ref()
        .map(|w| w.id.clone())
        .unwrap_or_default();
    let mut push = |invariant: &'static str, detail: String| {
        out.push(Violation {
            user: user.to_string(),
            workout_id: workout_id.clone(),
            step: step.to_string(),
            invariant,
            detail,
        });
    };
    let find = |id: &str| state.completed_sets.iter().find(|c| c.id == id);
    match expectation {
        Expectation::Rated {
            completed_set_id,
            effort,
        } => {
            if let Some(c) = find(completed_set_id) {
                if c.effort != *effort as i32 {
                    push(
                        "rate_exercise on a set that asked did not record the answer",
                        format!("set {} effort {} wanted {effort:?}", c.id, c.effort),
                    );
                }
            }
        }
        Expectation::RateNoop {
            completed_set_id,
            effort_before,
            proposed_before,
        } => {
            if let Some(c) = find(completed_set_id) {
                if c.effort != *effort_before {
                    push(
                        "rate_exercise on a set that never asked changed its effort",
                        format!("set {} effort {} -> {}", c.id, effort_before, c.effort),
                    );
                }
            }
            if state.proposed_sets.len() != *proposed_before {
                push(
                    "rate_exercise on a set that never asked changed the plan",
                    format!(
                        "{proposed_before} proposed sets -> {}",
                        state.proposed_sets.len()
                    ),
                );
            }
        }
        Expectation::Edited {
            completed_set_id,
            reps,
            weight,
        } => {
            if let Some(c) = find(completed_set_id) {
                if c.actual_reps != *reps || (c.actual_weight - weight).abs() > 0.01 {
                    push(
                        "edit_completed_set did not land",
                        format!(
                            "set {} is {}x{} wanted {reps}x{weight}",
                            c.id, c.actual_reps, c.actual_weight
                        ),
                    );
                }
                if c.rest_until < c.ended_at {
                    push(
                        "edit_completed_set put the rest before the set ended",
                        format!(
                            "set {} rest_until {} < ended_at {}",
                            c.id, c.rest_until, c.ended_at
                        ),
                    );
                }
            }
        }
    }
}

/// Everything we assert about a workout's state, checked after every mutation.
fn check_invariants(state: &GetWorkoutResponse, user: &str, step: &str, out: &mut Vec<Violation>) {
    let workout_id = state
        .workout
        .as_ref()
        .map(|w| w.id.clone())
        .unwrap_or_default();
    let mut push = |invariant: &'static str, detail: String| {
        out.push(Violation {
            user: user.to_string(),
            workout_id: workout_id.clone(),
            step: step.to_string(),
            invariant,
            detail,
        });
    };

    let proposed_ids: HashSet<&str> = state.proposed_sets.iter().map(|s| s.id.as_str()).collect();

    // Every completed set must point at a proposed set in this workout.
    for c in &state.completed_sets {
        if !proposed_ids.contains(c.proposed_set_id.as_str()) {
            push(
                "completed set references a proposed set that does not exist",
                format!("completed {} -> proposed {}", c.id, c.proposed_set_id),
            );
        }
    }

    // Only a warmup is ever skipped, and a skipped one is never up next.
    for p in state.proposed_sets.iter().filter(|p| p.skipped) {
        if !p.warmup {
            push("a working set is marked skipped", p.id.clone());
        }
        if state.next_up_set.as_ref().is_some_and(|n| n.id == p.id) {
            push("a skipped warmup is up next", p.id.clone());
        }
    }

    // A proposed set may be completed at most once.
    let mut seen: HashMap<&str, usize> = HashMap::new();
    for c in &state.completed_sets {
        *seen.entry(c.proposed_set_id.as_str()).or_default() += 1;
    }
    for (set_id, count) in seen.iter().filter(|(_, n)| **n > 1) {
        push(
            "a proposed set has more than one completed set",
            format!("proposed {set_id} completed {count} times"),
        );
    }

    // workout_order must be unique across live sets, or the UI reorders itself.
    let mut orders: HashMap<i32, usize> = HashMap::new();
    for s in state.proposed_sets.iter().filter(|s| !s.cancelled) {
        *orders.entry(s.workout_order).or_default() += 1;
    }
    for (order, count) in orders.iter().filter(|(_, n)| **n > 1) {
        push(
            "duplicate workout_order among live proposed sets",
            format!("order {order} used {count} times"),
        );
    }

    // next_up must be a live, not-yet-completed set — or, while the latest
    // done set is an unanswered calibration rung, the set its "right" would
    // append first: uuid5("{done_id}:0").
    let awaiting = state
        .completed_sets
        .iter()
        .filter(|c| c.ended_at != 0)
        .max_by_key(|c| c.ended_at)
        .filter(|c| {
            c.effort == Effort::Unspecified as i32
                && state
                    .proposed_sets
                    .iter()
                    .any(|p| p.id == c.proposed_set_id && p.calibration)
        })
        .map(|c| {
            uuid::Uuid::new_v5(&uuid::Uuid::NAMESPACE_OID, format!("{}:0", c.id).as_bytes())
                .to_string()
        });
    if let Some(expected) = awaiting.as_ref() {
        match state.next_up_set.as_ref() {
            Some(next) if &next.id == expected => {}
            other => push(
                "an unanswered rung does not point next_up_set at its {done}:0",
                format!("expected {expected} got {:?}", other.map(|n| &n.id)),
            ),
        }
        let display = state
            .state_snapshot
            .as_ref()
            .and_then(|snap| snap.display_set.as_ref())
            .map(|d| &d.id);
        if display != Some(expected) {
            push(
                "display_set and next_up_set disagree",
                format!("display {display:?} next_up {expected}"),
            );
        }
    } else if let Some(next) = state.next_up_set.as_ref() {
        let completed: HashSet<&str> = state
            .completed_sets
            .iter()
            .filter(|c| c.ended_at != 0)
            .map(|c| c.proposed_set_id.as_str())
            .collect();
        if !proposed_ids.contains(next.id.as_str()) {
            push(
                "next_up_set is not one of this workout's proposed sets",
                format!("next_up {}", next.id),
            );
        } else if next.cancelled {
            push("next_up_set is cancelled", format!("next_up {}", next.id));
        } else if completed.contains(next.id.as_str()) {
            push(
                "next_up_set has already been completed",
                format!("next_up {}", next.id),
            );
        }
    }

    // A set being lifted lives on the workout, never as an unfinished row.
    if let Some(c) = state.completed_sets.iter().find(|c| c.ended_at == 0) {
        push(
            "a completed set has no ended_at",
            format!("completed {}", c.id),
        );
    }
    // A done set's start, if any, is not after its Done.
    for c in &state.completed_sets {
        if c.started_at > c.ended_at {
            push(
                "a done set was started after it ended",
                format!("{} started {} ended {}", c.id, c.started_at, c.ended_at),
            );
        }
    }
    // LIFTING exactly when the marker points at a pending set, with that set
    // and its start.
    let workout = state.workout.clone().unwrap_or_default();
    let marker_pending = !workout.lifting_set_id.is_empty()
        && state
            .proposed_sets
            .iter()
            .any(|p| p.id == workout.lifting_set_id && !p.cancelled)
        && !state
            .completed_sets
            .iter()
            .any(|c| c.proposed_set_id == workout.lifting_set_id);
    if let Some(snap) = state.state_snapshot.as_ref() {
        let lifting = snap.state == WorkoutState::Lifting as i32;
        if lifting != marker_pending {
            push(
                "LIFTING disagrees with the workout's lifting marker",
                format!(
                    "state {} marker {:?} pending {marker_pending}",
                    snap.state, workout.lifting_set_id
                ),
            );
        } else if lifting
            && (snap.display_set.as_ref().map(|d| d.id.as_str())
                != Some(workout.lifting_set_id.as_str())
                || snap.lifting_started_at != workout.lifting_started_at)
        {
            push(
                "LIFTING does not show the set being lifted and its start",
                format!(
                    "display {:?} marker {} started {} vs {}",
                    snap.display_set.as_ref().map(|d| &d.id),
                    workout.lifting_set_id,
                    snap.lifting_started_at,
                    workout.lifting_started_at
                ),
            );
        }
    }

    // The prompt is the latest done set while it is prompt-worthy, with its
    // current answer; every older prompt-worthy set was answered by a Done.
    let latest = state
        .completed_sets
        .iter()
        .filter(|c| c.ended_at != 0)
        .max_by_key(|c| c.ended_at);
    let prompt = state
        .state_snapshot
        .as_ref()
        .and_then(|snap| snap.effort_prompt.as_ref());
    match (latest.filter(|c| prompt_worthy(state, c)), prompt) {
        (Some(c), Some(p)) if p.completed_set_id == c.id && p.effort == c.effort => {}
        (None, None) => {}
        (expected, got) => push(
            "effort_prompt does not describe the latest prompt-worthy done set",
            format!(
                "expected {:?} got {:?}",
                expected.map(|c| (&c.id, c.effort)),
                got.map(|p| (&p.completed_set_id, p.effort))
            ),
        ),
    }
    for c in state.completed_sets.iter().filter(|c| c.ended_at != 0) {
        if Some(&c.id) != latest.map(|l| &l.id)
            && prompt_worthy(state, c)
            && c.effort == Effort::Unspecified as i32
        {
            push(
                "an older prompt-worthy set was left unanswered past a Done",
                format!("set {}", c.id),
            );
        }
    }

    // The calibration ramp is capped at six rungs per exercise.
    let mut rungs: HashMap<i32, usize> = HashMap::new();
    for s in state
        .proposed_sets
        .iter()
        .filter(|s| s.calibration && !s.cancelled)
    {
        *rungs.entry(s.exercise).or_default() += 1;
    }
    for (exercise, count) in rungs.iter().filter(|(_, n)| **n > 6) {
        push(
            "more than six calibration rungs for one exercise",
            format!("exercise {exercise} has {count} rungs"),
        );
    }

    // An effort is one of the three answers or unanswered.
    for c in &state.completed_sets {
        if !(0..=3).contains(&c.effort) {
            push(
                "completed set has an unknown effort value",
                format!("set {} effort {}", c.id, c.effort),
            );
        }
    }

    // Weights and reps must be sane.
    for s in &state.proposed_sets {
        if s.target_weight < 0.0 || !s.target_weight.is_finite() {
            push(
                "proposed set has a nonsensical target weight",
                format!("set {} weight {}", s.id, s.target_weight),
            );
        }
        if s.target_reps < 0 {
            push(
                "proposed set has negative target reps",
                format!("set {} reps {}", s.id, s.target_reps),
            );
        }
    }
}

fn random_exercise(rng: &mut StdRng) -> Exercise {
    const LIFTS: [Exercise; 5] = [
        Exercise::Squat,
        Exercise::BenchPress,
        Exercise::Deadlift,
        Exercise::OverheadPress,
        Exercise::BarbellRow,
    ];
    LIFTS[rng.gen_range(0..LIFTS.len())]
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let mut violations: Vec<Violation> = Vec::new();
    let mut steps = 0usize;
    for user_idx in 0..args.users {
        let (v, s) = run_user(args.seed, user_idx, args.sessions);
        violations.extend(v);
        steps += s;
    }

    println!(
        "\n{} users x {} sessions, {} mutations checked",
        args.users, args.sessions, steps
    );

    if violations.is_empty() {
        println!("no invariant violations");
        return Ok(());
    }

    // Group identical invariants so a systemic bug reads as one finding.
    let mut by_invariant: HashMap<&str, Vec<&Violation>> = HashMap::new();
    for v in &violations {
        by_invariant.entry(v.invariant).or_default().push(v);
    }

    eprintln!("\n{} invariant violations:", violations.len());
    for (invariant, list) in &by_invariant {
        eprintln!("\n  {} ({} occurrences)", invariant, list.len());
        for v in list.iter().take(3) {
            eprintln!("    user={} workout={}", v.user, v.workout_id);
            eprintln!("    after: {}", v.step);
            eprintln!("    {}", v.detail);
        }
        if list.len() > 3 {
            eprintln!("    ... and {} more", list.len() - 3);
        }
    }
    eprintln!("\nreplay with --seed {}", args.seed);
    std::process::exit(1);
}
