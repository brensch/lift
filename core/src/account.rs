//! The account: everything one person has recorded, as the fold of their
//! events. `apply` is the only way it changes, and it runs the same on the
//! phone (to show a write now) and on the server (to keep its copy).

use std::collections::{BTreeMap, BTreeSet, HashSet};

use crate::events::{
    Event, Fact, HistoryImported, OverrideSet, ProgramEdited, ProgramSet, WorkoutStarted,
    WorkoutsEdit,
};
use crate::history::WorkoutRecord;
use crate::ids::Ids;
use crate::pb::{user_setting, ExerciseDecision, UserSetting, Workout};
use crate::plan::Override;
use crate::program::{Program, ProgramRef};
use crate::weight_units::{unit_from_proto, AppWeightUnit};
use crate::workout::{self as reducer, WorkoutError};

/// Why a write can't be made. Nothing changes when one is returned.
#[derive(Clone, Debug, PartialEq)]
pub enum CoreError {
    InvalidArgument(String),
    NotFound(String),
    FailedPrecondition(String),
}

impl std::fmt::Display for CoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidArgument(m) | Self::NotFound(m) | Self::FailedPrecondition(m) => {
                f.write_str(m)
            }
        }
    }
}

impl From<WorkoutError> for CoreError {
    fn from(error: WorkoutError) -> Self {
        match error {
            WorkoutError::FailedPrecondition(m) => Self::FailedPrecondition(m.to_string()),
        }
    }
}

fn invalid(message: impl Into<String>) -> CoreError {
    CoreError::InvalidArgument(message.into())
}

/// One program the account has had: who set it, when and why.
#[derive(Clone, Debug, PartialEq)]
pub struct ProgramVersion {
    /// The `ProgramSet` event's id.
    pub id: String,
    pub at: i64,
    pub author: String,
    pub note: String,
    pub program: ProgramRef,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Account {
    /// At most one per kind.
    pub settings: Vec<UserSetting>,
    /// Every program set, oldest first. The last is the one that plans; with
    /// none, the built-in program does.
    pub programs: Vec<ProgramVersion>,
    /// The program that plans: the last set, or the built-in one.
    pub program: ProgramRef,
    /// Per exercise: the weight a lift never done calibrates from (lb),
    /// from onboarding or imported history.
    pub starting_weights: BTreeMap<String, f32>,
    /// Per exercise: the user's latest override.
    pub overrides: BTreeMap<String, Override>,
    /// In the order they were started.
    pub workouts: Vec<WorkoutRecord>,
    /// The workout under way, or empty.
    pub active_workout_id: String,
    /// Sign-up is done.
    pub onboarded: bool,
    /// Heart-rate readings are left out: the server never reads them (the
    /// phone shows them), and they are most of what an account holds.
    pub without_heart_rate: bool,
}

impl Account {
    /// The account after `events`, in order. An event that can't apply
    /// (made by a different version of these rules) changes nothing.
    pub fn fold<'a>(events: impl IntoIterator<Item = &'a Event>) -> Self {
        Self::default().folding(events)
    }

    /// The same, without heart-rate readings: the server's account.
    pub fn fold_without_heart_rate<'a>(events: impl IntoIterator<Item = &'a Event>) -> Self {
        Self {
            without_heart_rate: true,
            ..Self::default()
        }
        .folding(events)
    }

    fn folding<'a>(mut self, events: impl IntoIterator<Item = &'a Event>) -> Self {
        for event in events {
            self.replay(event);
        }
        self
    }

    /// Fold in one event already in the log: it takes its place whether or
    /// not it applies. Returns why it didn't, if it didn't.
    pub fn replay(&mut self, event: &Event) -> Option<CoreError> {
        self.apply(event).err()
    }

    /// Apply a new event: all of it, or (on an error) none of it.
    pub fn apply(&mut self, event: &Event) -> Result<(), CoreError> {
        let mut ids = Ids::new(&event.id);
        let at = event.at;
        match &event.fact {
            Fact::WorkoutStarted(started) => self.start_workout(started, &event.id, &mut ids)?,
            Fact::HeartRateRecorded(recorded) => {
                let samples = recorded
                    .samples()
                    .ok_or_else(|| invalid("heart rate's gaps and bpms don't match"))?;
                let without = self.without_heart_rate;
                let workout = self.workout_mut(&recorded.workout_id)?;
                if !without {
                    workout.heart_rate = samples;
                }
            }
            Fact::ProgramSet(set) => self.set_program(set, &event.id, at),
            Fact::ProgramEdited(edited) => self.edit_program(edited)?,
            Fact::OverrideSet(set) => self.set_override(set, at)?,
            Fact::Onboarded(onboarded) => {
                if onboarded.unit != crate::pb::WeightUnit::Unspecified as i32 {
                    self.set_setting(UserSetting {
                        setting: Some(user_setting::Setting::WeightUnit(
                            crate::pb::WeightUnitConfig {
                                unit: onboarded.unit,
                            },
                        )),
                    })?;
                }
                for w in &onboarded.starting_weights {
                    self.starting_weights
                        .insert(w.exercise.clone(), w.weight_lb);
                }
                if self.program.workouts.is_empty() && !onboarded.workouts.is_empty() {
                    self.edit_program(&ProgramEdited {
                        edit: WorkoutsEdit::Add {
                            workouts: onboarded.workouts.clone(),
                        },
                    })?;
                }
                self.onboarded = true;
            }
            Fact::SettingUpdated(updated) => self.set_setting(updated.setting.clone())?,
            Fact::HistoryImported(imported) => self.import(imported),
            Fact::WorkoutDiscarded(discarded) => {
                let index = self
                    .workouts
                    .iter()
                    .position(|r| r.workout.id == discarded.workout_id)
                    .ok_or_else(|| CoreError::NotFound("Workout not found".into()))?;
                self.workouts.remove(index);
                if self.active_workout_id == discarded.workout_id {
                    self.active_workout_id.clear();
                }
            }
            // Recorded by a newer app: it folds once this one is updated.
            Fact::Unknown(unknown) => {
                return Err(invalid(format!(
                    "{} is not known to this version",
                    unknown.name
                )))
            }
            workout_fact => self.change_workout(workout_fact, at, &mut ids)?,
        }
        Ok(())
    }

    // ── Reads the rules need ──

    /// The unit the user picked; every snap and step rounds in it.
    pub fn unit(&self) -> AppWeightUnit {
        self.settings
            .iter()
            .find_map(|s| match &s.setting {
                Some(user_setting::Setting::WeightUnit(c)) => Some(unit_from_proto(c.unit)),
                _ => None,
            })
            .unwrap_or(AppWeightUnit::Lb)
    }

    /// The id of the program that plans; empty for the built-in one.
    pub fn program_id(&self) -> &str {
        self.programs.last().map_or("", |v| v.id.as_str())
    }

    /// The program set by event `id`; None for "" (the built-in one) or
    /// one this account never had.
    pub fn program_by_id(&self, id: &str) -> Option<&ProgramRef> {
        if id.is_empty() {
            return None;
        }
        self.programs
            .iter()
            .rev()
            .find(|v| v.id == id)
            .map(|v| &v.program)
    }

    pub fn workout(&self, id: &str) -> Option<&WorkoutRecord> {
        self.workouts.iter().find(|r| r.workout.id == id)
    }

    fn workout_mut(&mut self, id: &str) -> Result<&mut WorkoutRecord, CoreError> {
        self.workouts
            .iter_mut()
            .find(|r| r.workout.id == id)
            .ok_or_else(|| CoreError::NotFound("Workout not found".into()))
    }

    pub fn active_workout(&self) -> Option<&WorkoutRecord> {
        if self.active_workout_id.is_empty() {
            return None;
        }
        self.workout(&self.active_workout_id)
    }

    /// Every exercise the account names in its history, overrides and
    /// starting weights: what a program must keep.
    pub fn exercises_used(&self) -> BTreeSet<String> {
        let mut used: BTreeSet<String> = self
            .workouts
            .iter()
            .flat_map(|r| r.proposed_sets.iter().map(|s| s.exercise.clone()))
            .collect();
        used.extend(self.overrides.keys().cloned());
        used.extend(self.starting_weights.keys().cloned());
        used.remove("");
        used
    }

    // ── Writes ──

    /// A start: the workout, with the name and unit it started with, its
    /// sets laid out from the decisions recorded on the event by the
    /// program it was planned under. Nothing else of the account is read.
    fn start_workout(
        &mut self,
        req: &WorkoutStarted,
        workout_id: &str,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        let workout = Workout {
            id: workout_id.to_string(),
            name: req.name.clone(),
            start_time: req.started_at,
            template_id: req.template_id.clone(),
            motivation: req.motivation.clone(),
            ..Default::default()
        };
        let mut record = WorkoutRecord::new(workout, Vec::new(), Vec::new());
        let unit = unit_from_proto(req.unit);
        record.unit = unit;
        record.program = req
            .rules
            .as_ref()
            .map(|rules| ProgramRef::new(rules.program()))
            .unwrap_or_else(Program::builtin);
        require_decisions(&record, &req.exercises, &req.decisions)?;
        reducer::apply_add_exercises(&mut record, &req.decisions, unit, ids)?;
        self.workouts.push(record);
        self.active_workout_id = workout_id.to_string();
        Ok(())
    }

    /// One change to a workout, through the reducer. The workout is changed
    /// on a copy (without its heart rate) and put back, heart rate moved
    /// over, only if the whole change applied. It rounds in the workout's
    /// own unit.
    fn change_workout(&mut self, fact: &Fact, at: i64, ids: &mut Ids) -> Result<(), CoreError> {
        let workout_id = fact
            .workout_id()
            .ok_or_else(|| invalid("not a fact about a workout"))?;
        let index = self
            .workouts
            .iter()
            .position(|r| r.workout.id == workout_id)
            .ok_or_else(|| CoreError::NotFound("Workout not found".into()))?;
        let mut record = self.workouts[index].without_heart_rate();
        let unit = record.unit;
        match fact {
            Fact::SetCompleted(completed) => {
                reducer::apply_complete_set_to_active(&mut record, completed, unit, ids);
                // The target may be one the resolution just appended (a
                // rung's `{done_id}:0`), so it is checked after applying.
                if !record
                    .completed_sets
                    .iter()
                    .any(|c| c.proposed_set_id == completed.proposed_set_id)
                {
                    return Err(CoreError::FailedPrecondition(
                        "Proposed set not found".into(),
                    ));
                }
            }
            Fact::SetStarted(started) => reducer::apply_start_set_to_active(&mut record, started),
            Fact::WarmupsSkipped(skipped) => {
                reducer::apply_skip_warmups_to_active(&mut record, skipped)
            }
            Fact::RungAnswered(answered) => {
                reducer::apply_answer_rung_to_active(&mut record, answered, unit, at)
            }
            Fact::EffortAnswered(answered) => {
                reducer::apply_answer_effort_to_active(&mut record, answered)
            }
            Fact::SetUndone(undone) => {
                reducer::apply_delete_completed_set_to_active(&mut record, undone)
            }
            Fact::WorkoutEnded(ended) => {
                // Ending twice changes nothing.
                if record.workout.end_time > 0 {
                    return Ok(());
                }
                record.workout.end_time = ended.ended_at;
                if self.active_workout_id == record.workout.id {
                    self.active_workout_id.clear();
                }
            }
            Fact::ExercisesAdded(added) => {
                require_decisions(&record, &added.exercises, &added.decisions)?;
                if added
                    .definitions
                    .iter()
                    .any(|d| !record.program.knows(&d.key))
                {
                    record.program =
                        ProgramRef::new(record.program.with_exercises(&added.definitions));
                }
                reducer::apply_add_exercises(&mut record, &added.decisions, unit, ids)?
            }
            Fact::ExerciseAdjusted(adjusted) => {
                reducer::apply_adjust_exercise_weight(&mut record, adjusted, unit, ids, at)?
            }
            Fact::ExerciseRemoved(removed) => reducer::apply_remove_exercise(&mut record, removed)?,
            Fact::ExercisesReordered(reordered) => {
                reducer::apply_reorder_exercises(&mut record, reordered)?
            }
            Fact::SetEdited(edited) => {
                reducer::apply_edit_completed_set_to_active(&mut record, edited, unit, at)?
            }
            Fact::SessionSet(set) => record.workout.session_id = set.session_id.clone(),
            Fact::WorkoutEndMoved(moved) => {
                if record.workout.end_time == 0 {
                    return Err(invalid("the workout has not ended"));
                }
                record.workout.end_time = moved.ended_at;
                let end_ms = moved.ended_at * 1000;
                self.workouts[index]
                    .heart_rate
                    .retain(|s| s.sampled_at <= end_ms);
            }
            _ => return Err(invalid("not a fact about a workout")),
        }
        record.heart_rate = std::mem::take(&mut self.workouts[index].heart_rate);
        self.workouts[index] = record;
        Ok(())
    }

    /// A program, whole, as the one that plans from now on. Programs are
    /// checked when recorded (`api::Call::set_program`, and the server for
    /// a pushed one); the fold takes what was recorded.
    fn set_program(&mut self, set: &ProgramSet, id: &str, at: i64) {
        self.program = set.program.clone();
        self.programs.push(ProgramVersion {
            id: id.to_string(),
            at,
            author: set.author.clone(),
            note: set.note.clone(),
            program: set.program.clone(),
        });
    }

    /// An edit to the current program's workouts, if the program it
    /// leaves checks out.
    fn edit_program(&mut self, edited: &ProgramEdited) -> Result<(), CoreError> {
        let mut workouts = self.program.workouts.clone();
        match &edited.edit {
            WorkoutsEdit::Save { workout } => {
                match workouts.iter_mut().find(|w| w.id == workout.id) {
                    Some(existing) => *existing = workout.clone(),
                    None => workouts.push(workout.clone()),
                }
            }
            WorkoutsEdit::Delete { workout_id } => workouts.retain(|w| &w.id != workout_id),
            WorkoutsEdit::Reorder {
                workout_ids,
                rotation_count,
            } => {
                if rotation_count.is_some_and(|n| n < 0) {
                    return Err(invalid("rotation_count is negative"));
                }
                let rank = |id: &str| {
                    workout_ids
                        .iter()
                        .position(|w| w == id)
                        .unwrap_or(usize::MAX)
                };
                workouts.sort_by_key(|w| rank(&w.id));
                // The split is by place in the list given, a workout named
                // there but gone since counted: what the edit meant.
                if let Some(n) = rotation_count {
                    for w in workouts.iter_mut() {
                        if let Some(at) = workout_ids.iter().position(|id| *id == w.id) {
                            w.rotation = (at as i32) < *n;
                        }
                    }
                }
            }
            WorkoutsEdit::Add { workouts: added } => {
                for workout in added {
                    if !workouts.iter().any(|w| w.id == workout.id) {
                        workouts.push(workout.clone());
                    }
                }
            }
        }
        let program = self.program.with_workouts(workouts);
        if let Some(problem) = crate::program::check(&program)
            .into_iter()
            .find(|p| p.error)
        {
            return Err(invalid(format!("{}: {}", problem.path, problem.message)));
        }
        self.program = ProgramRef::new(program);
        Ok(())
    }

    fn set_setting(&mut self, setting: UserSetting) -> Result<(), CoreError> {
        let kind = setting_kind(&setting).ok_or_else(|| invalid("setting is empty"))?;
        self.settings.retain(|s| setting_kind(s) != Some(kind));
        self.settings.push(setting);
        Ok(())
    }

    /// The user's own weight and reps (and maybe sets) for a lift, replacing
    /// any before; reps of 0 removes it.
    fn set_override(&mut self, req: &OverrideSet, at: i64) -> Result<(), CoreError> {
        if !self.program.knows(&req.exercise) {
            return Err(invalid("Unknown exercise"));
        }
        if req.reps <= 0 {
            self.overrides.remove(&req.exercise);
            return Ok(());
        }
        if !(0.0..=2000.0).contains(&req.weight) || req.reps > 100 {
            return Err(invalid("Weight or reps out of range"));
        }
        if req.sets.is_some_and(|sets| !(1..=20).contains(&sets)) {
            return Err(invalid("Sets out of range"));
        }
        self.overrides.insert(
            req.exercise.clone(),
            Override {
                at,
                weight: req.weight,
                reps: req.reps,
                sets: req.sets,
            },
        );
        Ok(())
    }

    fn import(&mut self, req: &HistoryImported) {
        let mut held: HashSet<String> =
            self.workouts.iter().map(|r| r.workout.id.clone()).collect();
        for imported in &req.workouts {
            let Some(workout) = imported.workout.clone() else {
                continue;
            };
            if !held.insert(workout.id.clone()) {
                continue;
            }
            self.workouts.push(WorkoutRecord {
                workout,
                proposed_sets: imported.proposed_sets.clone(),
                completed_sets: imported.completed_sets.clone(),
                heart_rate: if self.without_heart_rate {
                    Vec::new()
                } else {
                    imported.heart_rate.clone()
                },
                exercise_logs: imported.exercise_logs.clone(),
                unit: self.unit(),
                program: self.program.clone(),
            });
        }
        self.workouts.sort_by_key(|r| r.workout.start_time);
        for w in &req.starting_weights {
            self.starting_weights
                .insert(w.exercise.clone(), w.weight_lb);
        }
    }
}

/// Every lift a start or an add names carries the decision recorded for
/// it, unless the workout already has one. The sets are laid out from the
/// decisions alone, so a lift named without one is refused rather than
/// folded into an empty workout.
fn require_decisions(
    record: &WorkoutRecord,
    exercises: &[String],
    decisions: &[ExerciseDecision],
) -> Result<(), CoreError> {
    let decided = |ex: &str| {
        decisions.iter().any(|d| d.exercise == ex)
            || record
                .exercise_logs
                .iter()
                .any(|log| log.decision.as_ref().is_some_and(|d| d.exercise == ex))
    };
    if exercises.iter().any(|ex| !ex.is_empty() && !decided(ex)) {
        return Err(invalid("A lift has no recorded decision"));
    }
    Ok(())
}

#[derive(Clone, Copy, PartialEq)]
enum SettingKind {
    PlateColors,
    WeightUnit,
}

fn setting_kind(setting: &UserSetting) -> Option<SettingKind> {
    match setting.setting {
        Some(user_setting::Setting::PlateColors(_)) => Some(SettingKind::PlateColors),
        Some(user_setting::Setting::WeightUnit(_)) => Some(SettingKind::WeightUnit),
        None => None,
    }
}
