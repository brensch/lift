//! A program run without being set, so whoever writes one can see what it
//! does before it plans anyone's training.
//!
//! **Over the history:** each finished workout's lifts, planned by the
//! draft as of just before it started (the workouts and overrides before
//! it, nothing after), beside the decision recorded then and what was
//! lifted.
//!
//! **Forward:** a copy of the account with the draft set, then `sessions`
//! workouts, `every_days` apart from now: the suggested rotation workout
//! each time (or `template_id`'s), started, every set done as the `effort`
//! says and ended — through the same API the app uses, so the warmups, the
//! calibration ramp and the time budget all run as they would. A lift never
//! done ramps up: its first two rungs are done in full, the third one rep
//! short, which settles it.
//!
//! Nothing of either is recorded on the account.

use std::collections::HashMap;

use crate::account::Account;
use crate::api::{problem_proto, Call};
use crate::history::WorkoutRecord;
use crate::pb::*;
use crate::plan::{Planner, DAY};
use crate::program::{self, Program, ProgramRef};
use crate::progress::compute_next_up_set;
use crate::recovery::per_muscle_recovery;
use crate::volume::{muscle_volume, suggest_template};

/// The most sessions a forward run takes.
pub const MAX_SESSIONS: i32 = 60;
/// The most past workouts a run plans again.
pub const MAX_HISTORY: i32 = 60;
/// What a set takes in a forward run, start to end.
const SET_SECONDS: i64 = 40;
/// The most sets one simulated workout does: a ramp, warmups and twenty
/// lifts' sets fit many times over.
const MOST_SETS: usize = 400;

pub fn simulate(
    account: &Account,
    now: i64,
    req: &SimulateProgramRequest,
) -> SimulateProgramResponse {
    let (draft, problems) = if req.program_json.trim().is_empty() {
        (account.program.clone(), Vec::new())
    } else {
        let (program, mut problems) = program::validate(&req.program_json);
        if let Some(program) = &program {
            problems.extend(program::validate_for_account(
                program,
                &account.exercises_used(),
            ));
        }
        match program {
            Some(program) if !problems.iter().any(|p| p.error) => {
                (ProgramRef::new(program), problems)
            }
            _ => {
                return SimulateProgramResponse {
                    problems: problems.iter().map(problem_proto).collect(),
                    workouts: Vec::new(),
                }
            }
        }
    };
    let mut workouts = backtest(account, &draft, req.history.clamp(0, MAX_HISTORY) as usize);
    workouts.extend(forward(account, draft, now, req));
    SimulateProgramResponse {
        problems: problems.iter().map(problem_proto).collect(),
        workouts,
    }
}

/// The last `count` finished workouts, each planned again by `draft` as of
/// just before it started.
fn backtest(account: &Account, draft: &Program, count: usize) -> Vec<SimulatedWorkout> {
    let mut finished: Vec<&WorkoutRecord> = account
        .workouts
        .iter()
        .filter(|r| r.workout.end_time > 0)
        .collect();
    finished.sort_by_key(|r| r.workout.start_time);
    let skip = finished.len().saturating_sub(count);
    finished
        .into_iter()
        .skip(skip)
        .map(|record| {
            let start = record.workout.start_time;
            let before = Account {
                workouts: account
                    .workouts
                    .iter()
                    .filter(|r| r.workout.start_time < start)
                    .cloned()
                    .collect(),
                overrides: account
                    .overrides
                    .iter()
                    .filter(|(_, o)| o.at < start)
                    .map(|(k, o)| (k.clone(), o.clone()))
                    .collect(),
                active_workout_id: String::new(),
                ..account.clone()
            };
            let recorded = first_decisions(record);
            let exercises: Vec<String> = recorded
                .iter()
                .map(|d| d.exercise.clone())
                .filter(|ex| draft.knows(ex))
                .collect();
            let budget = recorded.first().map_or(0, |d| d.budget_minutes);
            let planned =
                Planner::with_program(&before, draft, start).workout(&exercises, &[], budget);
            SimulatedWorkout {
                at: start,
                template_id: record.workout.template_id.clone(),
                name: record.workout.name.clone(),
                past: true,
                lifts: planned
                    .into_iter()
                    .map(|decision| {
                        let (done_weight, done_reps, hit) = lifted(record, &decision.exercise);
                        SimulatedLift {
                            exercise: decision.exercise.clone(),
                            recorded: recorded
                                .iter()
                                .find(|d| d.exercise == decision.exercise)
                                .cloned(),
                            decision: Some(decision),
                            done_weight,
                            done_reps,
                            hit,
                        }
                    })
                    .collect(),
            }
        })
        .collect()
}

/// Each lift's first decision in a workout, in the order planned.
fn first_decisions(record: &WorkoutRecord) -> Vec<ExerciseDecision> {
    let mut out: Vec<ExerciseDecision> = Vec::new();
    for d in record
        .exercise_logs
        .iter()
        .filter_map(|l| l.decision.as_ref())
    {
        if out.iter().all(|o| o.exercise != d.exercise) {
            out.push(d.clone());
        }
    }
    out
}

/// A lift's heaviest working set done in a workout (weight, reps), and
/// whether every working rep of it was hit.
fn lifted(record: &WorkoutRecord, exercise: &str) -> (f32, i32, bool) {
    let mut heaviest = (0.0_f32, 0);
    let mut hit = true;
    let mut any = false;
    for set in record
        .proposed_sets
        .iter()
        .filter(|s| s.exercise == exercise && s.is_working() && !s.cancelled)
    {
        match record
            .completed_sets
            .iter()
            .find(|c| c.proposed_set_id == set.id && c.ended_at > 0)
        {
            Some(done) => {
                any = true;
                hit &= done.actual_reps >= set.target_reps;
                if done.actual_weight > heaviest.0
                    || (done.actual_weight == heaviest.0 && done.actual_reps > heaviest.1)
                {
                    heaviest = (done.actual_weight, done.actual_reps);
                }
            }
            None => hit = false,
        }
    }
    (heaviest.0, heaviest.1, any && hit)
}

/// `sessions` workouts from now on a copy of the account with `draft` set.
fn forward(
    account: &Account,
    draft: ProgramRef,
    now: i64,
    req: &SimulateProgramRequest,
) -> Vec<SimulatedWorkout> {
    let sessions = req.sessions.clamp(0, MAX_SESSIONS);
    if sessions == 0 {
        return Vec::new();
    }
    let mut sim = account.clone();
    let mut ids = 0_u64;
    let mut next_id = || {
        ids += 1;
        format!("simulation-{ids}")
    };
    if *sim.program != *draft {
        let mut call = Call::new(&mut sim, now, next_id());
        if call
            .record_program((*draft).clone(), "simulation", "")
            .is_err()
        {
            return Vec::new();
        }
    }
    // A workout left under way is over before the run starts.
    if let Some(active) = sim.active_workout().map(|r| r.workout.id.clone()) {
        let mut call = Call::new(&mut sim, now, next_id());
        let _ = call.end_workout(EndWorkoutRequest {
            workout_id: active,
            ended_at: now,
        });
    }
    let every = i64::from(if req.every_days > 0 {
        req.every_days
    } else {
        2
    }) * DAY;
    let effort = SimulatedEffort::try_from(req.effort).unwrap_or(SimulatedEffort::AllHit);
    let mut out = Vec::new();
    for n in 0..sessions {
        let at = now + i64::from(n) * every;
        let Some(template_id) = pick(&sim, at, &req.template_id) else {
            break;
        };
        let started = {
            let mut call = Call::new(&mut sim, at, next_id());
            call.start_workout(StartWorkoutRequest {
                template_id: template_id.clone(),
                budget_minutes: req.budget_minutes,
                started_at: at,
                ..Default::default()
            })
        };
        let Ok(started) = started else {
            break;
        };
        let workout_id = started.id;
        let short_session = match effort {
            SimulatedEffort::MissEvery => req.miss_every > 0 && (n + 1) % req.miss_every == 0,
            _ => false,
        };
        let mut clock = at;
        let mut rungs: HashMap<String, usize> = HashMap::new();
        for _ in 0..MOST_SETS {
            let Some(record) = sim.workout(&workout_id) else {
                break;
            };
            let Some(set) = compute_next_up_set(&record.proposed_sets, &record.completed_sets)
            else {
                break;
            };
            let last_of_lift = !record.proposed_sets.iter().any(|s| {
                s.id != set.id
                    && s.exercise == set.exercise
                    && s.is_working()
                    && !s.cancelled
                    && !record
                        .completed_sets
                        .iter()
                        .any(|c| c.proposed_set_id == s.id)
            });
            let reps = if set.calibration {
                let rung = rungs.entry(set.exercise.clone()).or_default();
                *rung += 1;
                if *rung >= 3 {
                    set.target_reps - 1
                } else {
                    set.target_reps
                }
            } else if set.warmup {
                set.target_reps
            } else {
                let short = match effort {
                    SimulatedEffort::AllShort => true,
                    SimulatedEffort::LastSetShort => last_of_lift,
                    SimulatedEffort::MissEvery => short_session && last_of_lift,
                    _ => false,
                };
                if short {
                    set.target_reps - 1
                } else {
                    set.target_reps
                }
            }
            .max(0);
            let started_at = clock;
            clock += SET_SECONDS;
            let mut call = Call::new(&mut sim, clock, next_id());
            let done = call.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![
                    WorkoutMutation {
                        mutation: Some(workout_mutation::Mutation::StartSet(StartSetRequest {
                            workout_id: workout_id.clone(),
                            proposed_set_id: set.id.clone(),
                            started_at,
                        })),
                    },
                    WorkoutMutation {
                        mutation: Some(workout_mutation::Mutation::CompleteSet(
                            CompleteSetRequest {
                                workout_id: workout_id.clone(),
                                proposed_set_id: set.id.clone(),
                                actual_reps: reps,
                                actual_weight: set.target_weight,
                                completed_at: clock,
                            },
                        )),
                    },
                ],
            });
            if done.is_err() {
                break;
            }
            clock += i64::from(set.rest_seconds.max(0));
        }
        let mut call = Call::new(&mut sim, clock, next_id());
        let _ = call.end_workout(EndWorkoutRequest {
            workout_id: workout_id.clone(),
            ended_at: clock,
        });
        let Some(record) = sim.workout(&workout_id) else {
            break;
        };
        out.push(SimulatedWorkout {
            at,
            template_id,
            name: record.workout.name.clone(),
            past: false,
            lifts: first_decisions(record)
                .into_iter()
                .map(|decision| {
                    let (done_weight, done_reps, hit) = lifted(record, &decision.exercise);
                    SimulatedLift {
                        exercise: decision.exercise.clone(),
                        decision: Some(decision),
                        recorded: None,
                        done_weight,
                        done_reps,
                        hit,
                    }
                })
                .collect(),
        });
    }
    out
}

/// The workout to do at `at`: the one asked for, or the rotation's
/// suggestion, or the program's first workout.
fn pick(account: &Account, at: i64, asked: &str) -> Option<String> {
    let program = &account.program;
    if !asked.is_empty() {
        return program.workout(asked).map(|w| w.id.clone());
    }
    let volume = muscle_volume(program, &account.workouts, at);
    let recovery = per_muscle_recovery(program, &account.workouts);
    let mut last_started: HashMap<String, i64> = HashMap::new();
    for r in &account.workouts {
        let entry = last_started
            .entry(r.workout.template_id.clone())
            .or_default();
        *entry = (*entry).max(r.workout.start_time);
    }
    suggest_template(program, &volume, &recovery, at, &last_started)
        .map(|s| s.template_id)
        .or_else(|| program.workouts.first().map(|w| w.id.clone()))
}
