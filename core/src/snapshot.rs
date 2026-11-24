//! A folded account, written down so it can be picked up again: the server
//! keeps one per account (`account_snapshots`) and folds only the events
//! after it, instead of the whole log on every read.
//!
//! A snapshot is never the truth, only a shortcut to it: the events are.
//! `restore` of a snapshot taken after some events, then `replay` of the
//! rest, is the same account as folding all of them (`core/tests/snapshot.rs`
//! checks it). It is only good for the rules that wrote it, so whoever keeps
//! one stamps it with the build of these rules and throws it away when they
//! change.
//!
//! Programs are shared: every workout holds the program it was planned
//! under, mostly the same few. Each is written once and the workouts name
//! it by its place, so a year of workouts doesn't write the program a
//! hundred times, and a restored account shares them again.

use std::collections::BTreeMap;
use std::io::Read;
use std::sync::Arc;

use serde::{Deserialize, Serialize};

use crate::account::{Account, ProgramVersion, Suggestion};
use crate::events::ProgramSuggested;
use crate::history::WorkoutRecord;
use crate::pb::{CompletedSet, ExerciseLog, ProposedSet, UserSetting, Workout, WorkoutHeartRatePoint};
use crate::plan::Override;
use crate::program::{Program, ProgramRef};
use crate::weight_units::AppWeightUnit;

/// zstd's default level: snapshots are written now and then, read often.
const LEVEL: i32 = 3;

/// The most a snapshot may decompress to: far above any account, so a bad
/// row can't make a reader hold more than this.
const MAX_SNAPSHOT_BYTES: u64 = 512 << 20;

/// What a snapshot is: the account, and the programs it holds, once each.
#[derive(Serialize, Deserialize)]
struct Written {
    programs: Vec<Program>,
    account: Stored,
}

#[derive(Serialize, Deserialize)]
struct Stored {
    settings: Vec<UserSetting>,
    programs: Vec<StoredVersion>,
    program: usize,
    starting_weights: BTreeMap<String, f32>,
    overrides: BTreeMap<String, StoredOverride>,
    workouts: Vec<StoredWorkout>,
    suggestions: Vec<StoredSuggestion>,
    active_workout_id: String,
    onboarded: bool,
    without_heart_rate: bool,
}

#[derive(Serialize, Deserialize)]
struct StoredVersion {
    id: String,
    at: i64,
    author: String,
    note: String,
    program: usize,
}

#[derive(Serialize, Deserialize)]
struct StoredOverride {
    at: i64,
    weight: f32,
    reps: i32,
    sets: Option<i32>,
}

#[derive(Serialize, Deserialize)]
struct StoredWorkout {
    workout: Workout,
    proposed_sets: Vec<ProposedSet>,
    completed_sets: Vec<CompletedSet>,
    heart_rate: Vec<WorkoutHeartRatePoint>,
    exercise_logs: Vec<ExerciseLog>,
    kg: bool,
    program: usize,
}

#[derive(Serialize, Deserialize)]
struct StoredSuggestion {
    id: String,
    at: i64,
    suggested: ProgramSuggested,
    answer: Option<(bool, i64)>,
}

/// Each distinct program once, by the place it was first met.
#[derive(Default)]
struct Programs {
    places: Vec<(*const Program, usize)>,
    programs: Vec<Program>,
}

impl Programs {
    fn place(&mut self, program: &ProgramRef) -> usize {
        let key = Arc::as_ptr(&program.0);
        if let Some((_, place)) = self.places.iter().find(|(k, _)| *k == key) {
            return *place;
        }
        // The same document held twice (folded from two events) is still
        // written once.
        let place = match self.programs.iter().position(|p| p == &*program.0) {
            Some(place) => place,
            None => {
                self.programs.push((*program.0).clone());
                self.programs.len() - 1
            }
        };
        self.places.push((key, place));
        place
    }
}

/// The account, written down.
pub fn snapshot(account: &Account) -> Vec<u8> {
    // Every field by name: one added to `Account` doesn't compile here until
    // it is written down too.
    let Account {
        settings,
        programs,
        program,
        starting_weights,
        overrides,
        workouts,
        suggestions,
        active_workout_id,
        onboarded,
        without_heart_rate,
    } = account;
    let mut shared = Programs::default();
    let stored = Stored {
        settings: settings.clone(),
        programs: programs
            .iter()
            .map(|v| {
                let ProgramVersion {
                    id,
                    at,
                    author,
                    note,
                    program,
                } = v;
                StoredVersion {
                    id: id.clone(),
                    at: *at,
                    author: author.clone(),
                    note: note.clone(),
                    program: shared.place(program),
                }
            })
            .collect(),
        program: shared.place(program),
        starting_weights: starting_weights.clone(),
        overrides: overrides
            .iter()
            .map(|(lift, o)| {
                let Override {
                    at,
                    weight,
                    reps,
                    sets,
                } = o;
                (
                    lift.clone(),
                    StoredOverride {
                        at: *at,
                        weight: *weight,
                        reps: *reps,
                        sets: *sets,
                    },
                )
            })
            .collect(),
        workouts: workouts
            .iter()
            .map(|w| {
                let WorkoutRecord {
                    workout,
                    proposed_sets,
                    completed_sets,
                    heart_rate,
                    exercise_logs,
                    unit,
                    program,
                } = w;
                StoredWorkout {
                    workout: workout.clone(),
                    proposed_sets: proposed_sets.clone(),
                    completed_sets: completed_sets.clone(),
                    heart_rate: heart_rate.clone(),
                    exercise_logs: exercise_logs.clone(),
                    kg: *unit == AppWeightUnit::Kg,
                    program: shared.place(program),
                }
            })
            .collect(),
        suggestions: suggestions
            .iter()
            .map(|s| {
                let Suggestion {
                    id,
                    at,
                    suggested,
                    answer,
                } = s;
                StoredSuggestion {
                    id: id.clone(),
                    at: *at,
                    suggested: suggested.clone(),
                    answer: *answer,
                }
            })
            .collect(),
        active_workout_id: active_workout_id.clone(),
        onboarded: *onboarded,
        without_heart_rate: *without_heart_rate,
    };
    let written = Written {
        programs: shared.programs,
        account: stored,
    };
    // Plain data to a buffer, then compressed: neither can fail.
    let json = serde_json::to_vec(&written).expect("an account serialises");
    zstd::encode_all(json.as_slice(), LEVEL).expect("compressing to memory")
}

/// The account a snapshot holds; an error for one that doesn't read (cut
/// short, or written by other rules).
pub fn restore(snapshot: &[u8]) -> Result<Account, String> {
    let mut json = Vec::new();
    zstd::Decoder::new(snapshot)
        .map_err(|e| e.to_string())?
        .take(MAX_SNAPSHOT_BYTES)
        .read_to_end(&mut json)
        .map_err(|e| e.to_string())?;
    let Written { programs, account } =
        serde_json::from_slice(&json).map_err(|e| e.to_string())?;
    let programs: Vec<ProgramRef> = programs.into_iter().map(ProgramRef::new).collect();
    let program = |place: usize| {
        programs
            .get(place)
            .cloned()
            .ok_or_else(|| format!("no program {place} in the snapshot"))
    };
    Ok(Account {
        settings: account.settings,
        programs: account
            .programs
            .into_iter()
            .map(|v| {
                Ok(ProgramVersion {
                    id: v.id,
                    at: v.at,
                    author: v.author,
                    note: v.note,
                    program: program(v.program)?,
                })
            })
            .collect::<Result<_, String>>()?,
        program: program(account.program)?,
        starting_weights: account.starting_weights,
        overrides: account
            .overrides
            .into_iter()
            .map(|(lift, o)| {
                (
                    lift,
                    Override {
                        at: o.at,
                        weight: o.weight,
                        reps: o.reps,
                        sets: o.sets,
                    },
                )
            })
            .collect(),
        workouts: account
            .workouts
            .into_iter()
            .map(|w| {
                Ok(WorkoutRecord {
                    workout: w.workout,
                    proposed_sets: w.proposed_sets,
                    completed_sets: w.completed_sets,
                    heart_rate: w.heart_rate,
                    exercise_logs: w.exercise_logs,
                    unit: if w.kg {
                        AppWeightUnit::Kg
                    } else {
                        AppWeightUnit::Lb
                    },
                    program: program(w.program)?,
                })
            })
            .collect::<Result<_, String>>()?,
        suggestions: account
            .suggestions
            .into_iter()
            .map(|s| Suggestion {
                id: s.id,
                at: s.at,
                suggested: s.suggested,
                answer: s.answer,
            })
            .collect(),
        active_workout_id: account.active_workout_id,
        onboarded: account.onboarded,
        without_heart_rate: account.without_heart_rate,
    })
}
