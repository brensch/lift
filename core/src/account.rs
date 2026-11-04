//! The account: everything one person has recorded, as the fold of their
//! events. `apply` is the only way it changes, and it runs the same on the
//! phone (to show a write now) and on the server (to keep its copy).

use std::collections::BTreeMap;

use crate::events::{Event, Fact, HistoryImported, Onboarded, OverrideSet, WorkoutStarted};
use crate::history::WorkoutRecord;
use crate::ids::Ids;
use crate::pb::{
    user_setting, Exercise, ExerciseDecision, LibraryTemplate, UserSetting, WeightUnit,
    WeightUnitConfig, Workout, WorkoutTemplate,
};
use crate::plan::Override;
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

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Account {
    /// At most one per kind.
    pub settings: Vec<UserSetting>,
    /// In the user's order.
    pub templates: Vec<WorkoutTemplate>,
    /// Per exercise: the weight a lift never done calibrates from (lb),
    /// from onboarding or imported history.
    pub starting_weights: BTreeMap<i32, f32>,
    /// Per exercise: the user's latest override.
    pub overrides: BTreeMap<i32, Override>,
    /// In the order they were started.
    pub workouts: Vec<WorkoutRecord>,
    /// The workout under way, or empty.
    pub active_workout_id: String,
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
            Fact::TemplateSaved(saved) => {
                let mut template = saved.template.clone();
                // A library template stays coupled only while it is saved
                // unchanged; a real change makes it the user's own. New
                // templates are always the user's own.
                let keeps = self.template(&template.id).filter(|t| {
                    !saved.unlink
                        && t.coupled
                        && t.name == template.name
                        && t.exercises == template.exercises
                });
                match keeps {
                    Some(existing) => {
                        template.coupled = true;
                        template.library_id = existing.library_id.clone();
                    }
                    None => {
                        template.coupled = false;
                        template.library_id.clear();
                    }
                }
                // Where it came from outlives the coupling.
                template.origin_library_id = self
                    .template(&template.id)
                    .map(|t| t.origin_library_id.clone())
                    .unwrap_or_default();
                self.save_template(template, at, &mut ids)?;
            }
            Fact::TemplateDeleted(deleted) => {
                self.templates.retain(|t| t.id != deleted.template_id);
            }
            Fact::TemplatesReordered(reordered) => {
                if reordered.rotation_count.is_some_and(|n| n < 0) {
                    return Err(invalid("rotation_count is negative"));
                }
                for (order, id) in reordered.template_ids.iter().enumerate() {
                    if let Some(t) = self.templates.iter_mut().find(|t| &t.id == id) {
                        t.order = order as i32;
                        if let Some(n) = reordered.rotation_count {
                            t.in_rotation = (order as i32) < n;
                        }
                    }
                }
                self.sort_templates();
            }
            Fact::LibraryTemplatesAdded(added) => {
                for entry in &added.entries {
                    if self.templates.iter().any(|t| t.library_id == entry.id) {
                        continue; // already in the user's list
                    }
                    self.save_template(library_copy(entry, added.in_rotation), at, &mut ids)?;
                }
            }
            Fact::OverrideSet(set) => self.set_override(set, at)?,
            Fact::Onboarded(onboarded) => self.complete_onboarding(onboarded, at, &mut ids)?,
            Fact::SettingUpdated(updated) => {
                let setting = updated.setting.clone();
                let kind = setting_kind(&setting).ok_or_else(|| invalid("setting is empty"))?;
                self.settings.retain(|s| setting_kind(s) != Some(kind));
                self.settings.push(setting);
            }
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

    pub fn template(&self, id: &str) -> Option<&WorkoutTemplate> {
        self.templates.iter().find(|t| t.id == id)
    }

    /// The user has [library_id]: a template follows it or was made from it.
    pub fn has_library_entry(&self, library_id: &str) -> bool {
        self.templates.iter().any(|t| follows(t, library_id))
    }

    // ── Writes ──

    /// A start: the workout, with the name and unit it started with, its
    /// sets laid out from the decisions recorded on the event. Nothing else
    /// of the account is read.
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
            ..Default::default()
        };
        let mut record = WorkoutRecord::new(workout, Vec::new(), Vec::new());
        let unit = unit_from_proto(req.unit);
        record.unit = unit;
        require_decisions(&record, &req.exercises, &req.decisions)?;
        reducer::apply_add_exercises(&mut record, workout_id, &req.decisions, unit, ids)?;
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
                reducer::apply_complete_set_to_active(&mut record, completed, unit, ids)?;
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
            Fact::SetStarted(started) => reducer::apply_start_set_to_active(&mut record, started)?,
            Fact::WarmupsSkipped(skipped) => {
                reducer::apply_skip_warmups_to_active(&mut record, skipped)?
            }
            Fact::RungAnswered(answered) => {
                reducer::apply_answer_rung_to_active(&mut record, answered, unit, at)?
            }
            Fact::SetUndone(undone) => {
                reducer::apply_delete_completed_set_to_active(&mut record, undone)?
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
                reducer::apply_add_exercises(
                    &mut record,
                    &added.workout_id,
                    &added.decisions,
                    unit,
                    ids,
                )?
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
            _ => return Err(invalid("not a fact about a workout")),
        }
        record.heart_rate = std::mem::take(&mut self.workouts[index].heart_rate);
        self.workouts[index] = record;
        Ok(())
    }

    /// Create (empty id) or update a template.
    fn save_template(
        &mut self,
        mut template: WorkoutTemplate,
        at: i64,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        if template.name.trim().is_empty() {
            return Err(invalid("A template needs a name"));
        }
        if template.exercises.is_empty() {
            return Err(invalid("A template needs at least one exercise"));
        }
        if template.id.is_empty() {
            template.id = ids.new_id();
            template.created_at = at;
            template.order = self
                .templates
                .iter()
                .map(|t| t.order + 1)
                .max()
                .unwrap_or(0);
        } else if let Some(existing) = self.template(&template.id) {
            template.created_at = existing.created_at;
            template.order = existing.order;
        } else {
            template.created_at = at;
        }
        template.updated_at = at;
        self.templates.retain(|t| t.id != template.id);
        self.templates.push(template);
        self.sort_templates();
        Ok(())
    }

    fn sort_templates(&mut self) {
        self.templates.sort_by_key(|t| (t.order, t.created_at));
    }

    /// The user's own weight and reps (and maybe sets) for a lift, replacing
    /// any before; reps of 0 removes it.
    fn set_override(&mut self, req: &OverrideSet, at: i64) -> Result<(), CoreError> {
        Exercise::try_from(req.exercise)
            .ok()
            .filter(|ex| *ex != Exercise::Unspecified)
            .ok_or_else(|| invalid("Unknown exercise"))?;
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
            req.exercise,
            Override {
                at,
                weight: req.weight,
                reps: req.reps,
                sets: req.sets,
            },
        );
        Ok(())
    }

    /// The unit always; then, the first time only (no templates yet): the
    /// starting weights recorded on the event, and the library entries
    /// ticked (the defaults when none are named).
    fn complete_onboarding(
        &mut self,
        req: &Onboarded,
        at: i64,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        if req.unit != WeightUnit::Unspecified as i32 {
            self.settings
                .retain(|s| setting_kind(s) != Some(SettingKind::WeightUnit));
            self.settings.push(UserSetting {
                setting: Some(user_setting::Setting::WeightUnit(WeightUnitConfig {
                    unit: req.unit,
                })),
            });
        }
        if !self.templates.is_empty() {
            return Ok(());
        }
        for w in &req.starting_weights {
            self.starting_weights.insert(w.exercise, w.weight_lb);
        }
        // The workouts picked at onboarding are the rotation.
        for entry in &req.library_entries {
            self.save_template(library_copy(entry, true), at, ids)?;
        }
        Ok(())
    }

    fn import(&mut self, req: &HistoryImported) {
        for imported in &req.workouts {
            let Some(workout) = imported.workout.clone() else {
                continue;
            };
            if self.workout(&workout.id).is_some() {
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
            });
        }
        self.workouts.sort_by_key(|r| r.workout.start_time);
        for w in &req.starting_weights {
            self.starting_weights.insert(w.exercise, w.weight_lb);
        }
    }
}

/// Every lift a start or an add names carries the decision recorded for
/// it, unless the workout already has one. The sets are laid out from the
/// decisions alone, so a lift named without one (a log from before plans
/// were recorded) is refused rather than folded into an empty workout.
fn require_decisions(
    record: &WorkoutRecord,
    exercises: &[i32],
    decisions: &[ExerciseDecision],
) -> Result<(), CoreError> {
    let decided = |ex: i32| {
        decisions.iter().any(|d| d.exercise == ex)
            || record
                .exercise_logs
                .iter()
                .any(|log| log.decision.as_ref().is_some_and(|d| d.exercise == ex))
    };
    let undecided = exercises
        .iter()
        .filter(|ex| Exercise::try_from(**ex).is_ok_and(|ex| ex != Exercise::Unspecified))
        .any(|ex| !decided(*ex));
    if undecided {
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

/// A library entry in the user's list: a new template (empty id, given one
/// and an order on save), coupled to the entry and made from it, in
/// rotation or a reserve.
fn library_copy(entry: &LibraryTemplate, in_rotation: bool) -> WorkoutTemplate {
    WorkoutTemplate {
        in_rotation,
        name: entry.name.clone(),
        exercises: entry.exercises.clone(),
        library_id: entry.id.clone(),
        origin_library_id: entry.id.clone(),
        coupled: true,
        ..Default::default()
    }
}

/// [template] follows library entry [library_id] or was made from it.
pub fn follows(template: &WorkoutTemplate, library_id: &str) -> bool {
    template.library_id == library_id || template.origin_library_id == library_id
}
