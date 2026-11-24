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
//! Written as an `AccountSnapshot` (proto/workout/v1/snapshot.proto), zstd
//! compressed: about a quarter of the size of the same account as JSON,
//! and decoded several times faster. Programs are shared: every workout holds the program it was planned
//! under, mostly the same few. Each is written once and the workouts name
//! it by its place, so a year of workouts doesn't write the program a
//! hundred times, and a restored account shares them again.

use std::io::Read;
use std::sync::Arc;

use prost::Message;

use crate::account::{Account, ProgramVersion, Suggestion};
use crate::history::WorkoutRecord;
use crate::pb::{
    AccountSnapshot, SnapshotOverride, SnapshotProgramVersion, SnapshotStartingWeight,
    SnapshotSuggestion, SnapshotWorkout,
};
use crate::plan::Override;
use crate::program::{Program, ProgramRef};
use crate::weight_units::AppWeightUnit;

/// zstd's fastest levels lose little here: snapshots are written often.
const LEVEL: i32 = 1;

/// The most a snapshot may decompress to: far above any account, so a bad
/// one can't make a reader hold more than this.
const MAX_SNAPSHOT_BYTES: u64 = 512 << 20;

/// Each distinct program once, by the place it was first met.
#[derive(Default)]
struct Programs {
    places: Vec<(*const Program, u32)>,
    programs: Vec<Program>,
}

impl Programs {
    fn place(&mut self, program: &ProgramRef) -> u32 {
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
        } as u32;
        self.places.push((key, place));
        place
    }
}

/// The account as folded up to `seq`, as a message.
pub fn encode(account: &Account, seq: i64) -> AccountSnapshot {
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
    let versions = programs
        .iter()
        .map(|v| {
            let ProgramVersion {
                id,
                at,
                author,
                note,
                program,
            } = v;
            SnapshotProgramVersion {
                id: id.clone(),
                at: *at,
                author: author.clone(),
                note: note.clone(),
                program: shared.place(program),
            }
        })
        .collect();
    let program = shared.place(program);
    let workouts = workouts
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
            SnapshotWorkout {
                workout: Some(workout.clone()),
                proposed_sets: proposed_sets.clone(),
                completed_sets: completed_sets.clone(),
                exercise_logs: exercise_logs.clone(),
                kg: *unit == AppWeightUnit::Kg,
                program: shared.place(program),
                heart_rate: heart_rate.clone(),
            }
        })
        .collect();
    AccountSnapshot {
        fold: crate::FOLD.to_string(),
        seq,
        // Plain data: serialising it can't fail.
        programs: shared
            .programs
            .iter()
            .map(|p| serde_json::to_string(p).expect("a program serialises"))
            .collect(),
        settings: settings.clone(),
        versions,
        program,
        starting_weights: starting_weights
            .iter()
            .map(|(lift, weight)| SnapshotStartingWeight {
                lift: lift.clone(),
                weight: *weight,
            })
            .collect(),
        overrides: overrides
            .iter()
            .map(|(lift, o)| {
                let Override {
                    at,
                    weight,
                    reps,
                    sets,
                } = o;
                SnapshotOverride {
                    lift: lift.clone(),
                    at: *at,
                    weight: *weight,
                    reps: *reps,
                    has_sets: sets.is_some(),
                    sets: sets.unwrap_or_default(),
                }
            })
            .collect(),
        workouts,
        suggestions: suggestions
            .iter()
            .map(|s| {
                let Suggestion {
                    id,
                    at,
                    suggested,
                    answer,
                } = s;
                SnapshotSuggestion {
                    id: id.clone(),
                    at: *at,
                    suggested: serde_json::to_string(suggested).expect("a suggestion serialises"),
                    answered: answer.is_some(),
                    accepted: answer.is_some_and(|(accepted, _)| accepted),
                    answered_at: answer.map_or(0, |(_, at)| at),
                }
            })
            .collect(),
        active_workout_id: active_workout_id.clone(),
        onboarded: *onboarded,
        without_heart_rate: *without_heart_rate,
    }
}

/// The account a message holds, and the seq it was folded up to. An error
/// for one folded by other rules, or that doesn't read.
pub fn decode(snapshot: AccountSnapshot) -> Result<(Account, i64), String> {
    if snapshot.fold != crate::FOLD {
        return Err(format!(
            "folded by other rules ({}, not {})",
            snapshot.fold,
            crate::FOLD
        ));
    }
    let programs = snapshot
        .programs
        .iter()
        .map(|json| serde_json::from_str::<Program>(json).map(ProgramRef::new))
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;
    let program = |place: u32| {
        programs
            .get(place as usize)
            .cloned()
            .ok_or_else(|| format!("no program {place} in the snapshot"))
    };
    let account = Account {
        settings: snapshot.settings,
        programs: snapshot
            .versions
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
        program: program(snapshot.program)?,
        starting_weights: snapshot
            .starting_weights
            .into_iter()
            .map(|w| (w.lift, w.weight))
            .collect(),
        overrides: snapshot
            .overrides
            .into_iter()
            .map(|o| {
                (
                    o.lift,
                    Override {
                        at: o.at,
                        weight: o.weight,
                        reps: o.reps,
                        sets: o.has_sets.then_some(o.sets),
                    },
                )
            })
            .collect(),
        workouts: snapshot
            .workouts
            .into_iter()
            .map(|w| {
                Ok(WorkoutRecord {
                    workout: w.workout.unwrap_or_default(),
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
        suggestions: snapshot
            .suggestions
            .into_iter()
            .map(|s| {
                Ok(Suggestion {
                    id: s.id,
                    at: s.at,
                    suggested: serde_json::from_str(&s.suggested).map_err(|e| e.to_string())?,
                    answer: s.answered.then_some((s.accepted, s.answered_at)),
                })
            })
            .collect::<Result<_, String>>()?,
        active_workout_id: snapshot.active_workout_id,
        onboarded: snapshot.onboarded,
        without_heart_rate: snapshot.without_heart_rate,
    };
    Ok((account, snapshot.seq))
}

/// The account as folded up to `seq`, written down: the message, zstd
/// compressed.
pub fn snapshot(account: &Account, seq: i64) -> Vec<u8> {
    let bytes = encode(account, seq).encode_to_vec();
    zstd::encode_all(bytes.as_slice(), LEVEL).expect("compressing to memory")
}

/// A snapshot folded by any rules, as best it reads: what a phone shows
/// after an update, until the server sends the account by the new ones.
pub fn restore_by_any_rules(snapshot: &[u8]) -> Result<(Account, i64), String> {
    let mut message = read(snapshot)?;
    message.fold = crate::FOLD.to_string();
    decode(message)
}

fn read(snapshot: &[u8]) -> Result<AccountSnapshot, String> {
    let mut bytes = Vec::new();
    zstd::Decoder::new(snapshot)
        .map_err(|e| e.to_string())?
        .take(MAX_SNAPSHOT_BYTES)
        .read_to_end(&mut bytes)
        .map_err(|e| e.to_string())?;
    AccountSnapshot::decode(bytes.as_slice()).map_err(|e| e.to_string())
}

/// What `snapshot` wrote: the account and its seq. An error for one folded
/// by other rules, cut short, or that doesn't read.
pub fn restore(snapshot: &[u8]) -> Result<(Account, i64), String> {
    decode(read(snapshot)?)
}
