//! Drives the core through randomised but realistic workout sessions and
//! asserts invariants after every mutation.
//!
//! This exists to find the bugs unit tests do not: ones that need a specific
//! *sequence* of operations (edit a plan mid-set, delete a completed set, skip
//! warmups, reorder groups, set an override, edit a done set, end twice).
//!
//! It runs the core in-process, as the phone does. Every start is checked
//! against Home's preview at the same moment and budget, and the folded
//! workout against the decisions it recorded; after every user, replaying
//! their recorded events must rebuild the same account.
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
    AnswerRungRequest, AppendWorkoutMutationsRequest, ApplyLibraryPlanRequest,
    CompleteOnboardingRequest, CompleteSetRequest, CompletedSet, DeleteCompletedSetRequest,
    EditCompletedSetRequest, EndWorkoutRequest, Event, Exercise, ExerciseDecision, ExercisePlan,
    GetHomeRequest, GetWorkoutRequest, GetWorkoutResponse, PlanReasonKind, RemoveExerciseRequest,
    ReorderExercisesRequest, RepsLeft, SetOverrideRequest, SkipWarmupsRequest, StartSetRequest,
    StartWorkoutRequest, WeightUnit, WorkoutMutation, WorkoutState,
};
use schlift_core::plan::Planner;

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

    // Onboard as the app does: the default templates, and starting weights
    // from the strength slider half the time.
    let templates = match sim
        .call(now)
        .complete_onboarding(CompleteOnboardingRequest {
            unit: if rng.gen_bool(0.3) {
                WeightUnit::Kg as i32
            } else {
                WeightUnit::Lb as i32
            },
            strength: rng
                .gen_bool(0.5)
                .then(|| rng.gen_range(0..=100) as f32 / 100.0),
            ..Default::default()
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

    // A third of users then pick a ready-made plan: it is the main plan
    // afterwards, in its order.
    let plans = schlift_core::template_library::plans();
    let templates = if !plans.is_empty() && rng.gen_bool(0.3) {
        let plan = &plans[rng.gen_range(0..plans.len())];
        match sim.call(now).apply_library_plan(ApplyLibraryPlanRequest {
            plan_id: plan.id.clone(),
        }) {
            Ok(r) => {
                let after = r.home.map(|h| h.templates).unwrap_or_default();
                let main: Vec<&str> = after
                    .iter()
                    .filter(|t| t.in_rotation)
                    .map(|t| t.origin_library_id.as_str())
                    .collect();
                if main != plan.library_ids {
                    violations.push(Violation {
                        user: username.clone(),
                        workout_id: String::new(),
                        step: "apply_library_plan".into(),
                        invariant: "a ready-made plan is not the main plan after applying it",
                        detail: format!("{} gave {main:?}", plan.id),
                    });
                }
                after
            }
            Err(e) => {
                violations.push(Violation {
                    user: username.clone(),
                    workout_id: String::new(),
                    step: "apply_library_plan".into(),
                    invariant: "ApplyLibraryPlan returned an error",
                    detail: e.to_string(),
                });
                templates
            }
        }
    } else {
        templates
    };

    // Time only moves forward: a session two days after the last one ended,
    // sometimes weeks later so the time-off cut is exercised.
    let mut clock = now;
    for session_idx in 0..sessions {
        let at_time = clock
            + 2 * 86_400
            + if rng.gen_bool(0.15) {
                rng.gen_range(15..70) * 86_400
            } else {
                0
            };

        // Half the sessions start from a template (the app's main path);
        // the rest send explicit exercises (the "empty workout" path). What
        // Home previews at the same moment and budget is what the start
        // must record.
        let budget = [0, 15, 30, 45, 60, 90][rng.gen_range(0..6)];
        let (request, preview) = if !templates.is_empty() && rng.gen_bool(0.5) {
            let template = &templates[rng.gen_range(0..templates.len())];
            let preview: Vec<ExerciseDecision> = sim
                .view(at_time)
                .get_home(GetHomeRequest {
                    budget_minutes: budget,
                })
                .map(|home| home.template_plans)
                .unwrap_or_default()
                .into_iter()
                .find(|p| p.template_id == template.id)
                .map(|p| p.plans.into_iter().filter_map(|p| p.decision).collect())
                .unwrap_or_default();
            let request = StartWorkoutRequest {
                started_at: at_time,
                template_id: template.id.clone(),
                budget_minutes: budget,
                ..Default::default()
            };
            (request, preview)
        } else {
            // Sometimes with a lift twice: it is planned once.
            let exercises: Vec<Exercise> = (0..rng.gen_range(1..5))
                .map(|_| random_exercise(&mut rng))
                .collect();
            let mut once: Vec<Exercise> = Vec::new();
            for ex in &exercises {
                if !once.contains(ex) {
                    once.push(*ex);
                }
            }
            let preview = Planner::new(&sim.account, at_time).workout(&once, &[], budget);
            let request = StartWorkoutRequest {
                name: format!("Fuzz {session_idx}"),
                exercises: exercises.iter().map(|e| *e as i32).collect(),
                started_at: at_time,
                budget_minutes: budget,
                ..Default::default()
            };
            (request, preview)
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
        let recorded: Vec<ExerciseDecision> = started
            .exercise_logs
            .iter()
            .filter_map(|l| l.decision.clone())
            .collect();
        if recorded != preview {
            violations.push(Violation {
                user: username.clone(),
                workout_id: workout_id.clone(),
                step: "start_workout".into(),
                invariant: "a start recorded other decisions than the preview at that moment",
                detail: format!("{} recorded, {} previewed", recorded.len(), preview.len()),
            });
        }
        check_laid_out(
            &started.proposed_sets,
            &recorded,
            &username,
            &workout_id,
            &mut violations,
        );

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
                    step_name = format!("complete_set({})", set.id);
                    now += 45;
                    let _ = sim.call(now).complete_set(CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: set.id.clone(),
                        actual_reps: rng.gen_range(0..12),
                        actual_weight: set.target_weight,
                        completed_at: now,
                    });
                    now += 90;
                    // A ramp set done in full asks how many more: usually
                    // answered (the phone's sheet, the watch's row), and now
                    // and then an answer arrives for a set it no longer
                    // applies to (a stale watch tap).
                    if let Ok(after) = sim.view(now).get_workout(GetWorkoutRequest {
                        workout_id: workout_id.clone(),
                    }) {
                        let open = after.rung_question_set_id.clone();
                        let target = if !open.is_empty() && rng.gen_bool(0.6) {
                            Some(open.clone())
                        } else if !after.completed_sets.is_empty() && rng.gen_bool(0.15) {
                            let c =
                                &after.completed_sets[rng.gen_range(0..after.completed_sets.len())];
                            Some(c.proposed_set_id.clone())
                        } else {
                            None
                        };
                        if let Some(target) = target {
                            let reps_left = [
                                RepsLeft::ZeroToOne,
                                RepsLeft::TwoToThree,
                                RepsLeft::FourPlus,
                            ][rng.gen_range(0..3)];
                            let _ = sim.call(now).append_workout_mutations(
                                AppendWorkoutMutationsRequest {
                                    mutations: vec![mutation_at(
                                        Mutation::AnswerRung(AnswerRungRequest {
                                            workout_id: workout_id.clone(),
                                            proposed_set_id: target.clone(),
                                            reps_left: reps_left as i32,
                                        }),
                                        now,
                                    )],
                                },
                            );
                            expect = Some(if target == open {
                                Expectation::Answered {
                                    proposed_set_id: target,
                                    reps_left: reps_left as i32,
                                }
                            } else {
                                Expectation::Unchanged {
                                    before: Box::new(after),
                                }
                            });
                        }
                    }
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
                        ..Default::default()
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
            } else if action < 82 && !state.proposed_sets.is_empty() {
                // The user sets a lift by hand: it is planned as given.
                let s = &state.proposed_sets[rng.gen_range(0..state.proposed_sets.len())];
                let reps = rng.gen_range(1..15);
                let sets = rng.gen_bool(0.5).then(|| rng.gen_range(1..7));
                step_name = format!("set_override({})", s.exercise);
                expect = Some(Expectation::Override {
                    exercise: s.exercise,
                    reps,
                    sets,
                });
                let _ = sim.call(now).set_override(SetOverrideRequest {
                    exercise: s.exercise,
                    weight: (rng.gen_range(9..60) * 5) as f32,
                    reps,
                    sets,
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
                    let plan = match &expectation {
                        Expectation::Override { exercise, .. } => Exercise::try_from(*exercise)
                            .ok()
                            .map(|ex| sim.view(now).exercise_plan(ex, 0)),
                        _ => None,
                    };
                    check_expectation(
                        &after,
                        plan.as_ref(),
                        &expectation,
                        &username,
                        &step_name,
                        &mut violations,
                    );
                }
            }
        }

        // End the workout, sometimes twice — EndWorkout must be idempotent,
        // and a re-fire must not change any plan.
        let _ = sim.call(now).end_workout(EndWorkoutRequest {
            workout_id: workout_id.clone(),
            ended_at: now,
        });
        if rng.gen_bool(0.25) {
            let before = home_plans(sim.view(now));
            let _ = sim.call(now).end_workout(EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ended_at: now,
            });
            if home_plans(sim.view(now)) != before {
                violations.push(Violation {
                    user: username.clone(),
                    workout_id: workout_id.clone(),
                    step: "end_workout(again)".into(),
                    invariant: "a re-fired EndWorkout changed a plan",
                    detail: String::new(),
                });
            }
        }

        clock = now;

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

/// Every lift's plan on Home.
fn home_plans(view: View) -> Vec<ExercisePlan> {
    view.get_home(GetHomeRequest::default())
        .map(|home| home.plans)
        .unwrap_or_default()
}

/// A start's sets are its decisions laid out: per lift, a ramp's first rung
/// at the decision's weight, or its working sets at the decision's sets,
/// reps and weight with a warmup ladder exactly when it has one.
fn check_laid_out(
    sets: &[schlift_core::pb::ProposedSet],
    decisions: &[ExerciseDecision],
    user: &str,
    workout_id: &str,
    out: &mut Vec<Violation>,
) {
    for d in decisions {
        let mine: Vec<_> = sets.iter().filter(|s| s.exercise == d.exercise).collect();
        let working: Vec<_> = mine.iter().filter(|s| !s.warmup).collect();
        let laid_out = if d.calibration {
            mine.len() == 1 && mine[0].calibration && mine[0].target_weight == d.weight
        } else {
            working.len() == d.sets as usize
                && working.iter().all(|s| {
                    s.target_weight == d.weight
                        && s.target_reps == d.reps
                        && s.rest_seconds == d.rest_seconds
                        && !s.calibration
                })
                && mine.iter().any(|s| s.warmup) == d.warmups
        };
        if !laid_out {
            out.push(Violation {
                user: user.to_string(),
                workout_id: workout_id.to_string(),
                step: "start_workout".into(),
                invariant: "the started workout is not its recorded decisions laid out",
                detail: format!("{d:?}"),
            });
        }
    }
}

fn mutation_at(mutation: Mutation, at: i64) -> WorkoutMutation {
    WorkoutMutation {
        event_id: uuid::Uuid::new_v4().to_string(),
        client_created_at: at,
        mutation: Some(mutation),
    }
}

/// What one of the new mutations promised about the state after it.
enum Expectation {
    /// An override: the lift's next plan is it.
    Override {
        exercise: i32,
        reps: i32,
        sets: Option<i32>,
    },
    Edited {
        completed_set_id: String,
        reps: i32,
        weight: f32,
    },
    /// The open rung question answered: recorded, and closed.
    Answered {
        proposed_set_id: String,
        reps_left: i32,
    },
    /// An answer to a set with no open question: a no-op.
    Unchanged { before: Box<GetWorkoutResponse> },
}

fn check_expectation(
    state: &GetWorkoutResponse,
    plan: Option<&ExercisePlan>,
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
        Expectation::Override {
            exercise,
            reps,
            sets,
        } => {
            let decision = plan.and_then(|p| p.decision.as_ref());
            let as_set = plan.is_some_and(|p| p.overridden)
                && decision.is_some_and(|d| {
                    d.exercise == *exercise
                        && d.reps == *reps
                        && sets.is_none_or(|n| d.sets == n)
                        && d.reasons.first().map(|r| r.kind) == Some(PlanReasonKind::UserSet as i32)
                });
            if !as_set {
                push(
                    "an override is not the lift's next plan",
                    format!("{reps} reps, {sets:?} sets: {decision:?}"),
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
        Expectation::Answered {
            proposed_set_id,
            reps_left,
        } => {
            let recorded = state
                .completed_sets
                .iter()
                .any(|c| c.proposed_set_id == *proposed_set_id && c.reps_left == *reps_left);
            if !recorded || state.rung_question_set_id == *proposed_set_id {
                push(
                    "an answer to the open rung question did not land",
                    format!(
                        "set {proposed_set_id}: recorded {recorded}, still asking {}",
                        state.rung_question_set_id
                    ),
                );
            }
        }
        Expectation::Unchanged { before } => {
            if state.proposed_sets != before.proposed_sets
                || state.completed_sets != before.completed_sets
                || state.exercise_logs != before.exercise_logs
            {
                push(
                    "an answer with no open question changed the workout",
                    String::new(),
                );
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

    // next_up must be a live, not-yet-completed set.
    if let Some(next) = state.next_up_set.as_ref() {
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
    const LIFTS: [Exercise; 8] = [
        Exercise::Squat,
        Exercise::BenchPress,
        Exercise::Deadlift,
        Exercise::OverheadPress,
        Exercise::BarbellRow,
        Exercise::LateralRaise,
        Exercise::CableCrunch,
        Exercise::PullUp,
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
