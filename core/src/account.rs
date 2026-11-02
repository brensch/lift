//! The account: everything one person has recorded, as the fold of their
//! events. `apply` is the only way it changes, and it runs the same on the
//! phone (to show a write now) and on the server (to keep its copy).

use std::collections::BTreeMap;

use crate::history::WorkoutRecord;
use crate::ids::Ids;
use crate::pb::{
    event, user_setting, workout_mutation::Mutation, CompleteOnboardingRequest, Event, Exercise,
    ExerciseDecision, ImportHistory, LibraryTemplate, SetOverrideRequest, StartWorkoutRequest,
    UserSetting, WeightUnit, WeightUnitConfig, Workout, WorkoutMutation, WorkoutTemplate,
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
            WorkoutError::FailedPrecondition(m) | WorkoutError::Internal(m) => {
                Self::FailedPrecondition(m.to_string())
            }
        }
    }
}

fn invalid(message: impl Into<String>) -> CoreError {
    CoreError::InvalidArgument(message.into())
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Account {
    /// The last event folded in; the next one is `seq + 1`.
    pub seq: i64,
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
}

impl Account {
    /// The account after `events`, in order. An event that can't apply
    /// (made by a different version of these rules) changes nothing.
    pub fn fold<'a>(events: impl IntoIterator<Item = &'a Event>) -> Self {
        let mut account = Self::default();
        for event in events {
            account.replay(event);
        }
        account
    }

    /// Fold in one event already in the log: it takes its place whether or
    /// not it applies. Returns why it didn't, if it didn't.
    pub fn replay(&mut self, event: &Event) -> Option<CoreError> {
        let error = self.apply(event).err();
        self.seq = self.seq.max(event.seq);
        error
    }

    /// Apply a new event: all of it, or (on an error) none of it.
    pub fn apply(&mut self, event: &Event) -> Result<(), CoreError> {
        let mut ids = Ids::new(&event.id);
        let at = event.at;
        let kind = event
            .kind
            .as_ref()
            .ok_or_else(|| invalid("event has no kind"))?;
        match kind {
            event::Kind::StartWorkout(req) => self.start_workout(req, &event.id, at, &mut ids)?,
            event::Kind::Workout(mutation) => self.mutate_workout(mutation, at, &mut ids)?,
            event::Kind::HeartRate(req) => {
                self.workout_mut(&req.workout_id)?
                    .heart_rate
                    .extend(req.samples.iter().cloned());
            }
            event::Kind::SaveTemplate(req) => {
                let mut template = req
                    .template
                    .clone()
                    .ok_or_else(|| invalid("template is required"))?;
                // A library template stays coupled only while it is saved
                // unchanged; a real change makes it the user's own. New
                // templates are always the user's own.
                let keeps = self.template(&template.id).filter(|t| {
                    !req.unlink
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
                self.save_template(template, at, &mut ids)?;
            }
            event::Kind::CloneTemplate(req) => {
                let template = self
                    .templates
                    .iter_mut()
                    .find(|t| t.id == req.template_id)
                    .ok_or_else(|| CoreError::NotFound("Template not found".into()))?;
                template.coupled = false;
                template.library_id.clear();
                if !req.name.trim().is_empty() {
                    template.name = req.name.clone();
                }
                if !req.exercises.is_empty() {
                    template.exercises = req.exercises.clone();
                }
                template.updated_at = at;
            }
            event::Kind::DeleteTemplate(req) => {
                self.templates.retain(|t| t.id != req.template_id);
            }
            event::Kind::ReorderTemplates(req) => {
                for (order, id) in req.template_ids.iter().enumerate() {
                    if let Some(t) = self.templates.iter_mut().find(|t| &t.id == id) {
                        t.order = order as i32;
                    }
                }
                self.sort_templates();
            }
            event::Kind::AddLibraryTemplates(req) => {
                for entry in library_entries(&req.entries, &req.library_ids)? {
                    if self.templates.iter().any(|t| t.library_id == entry.id) {
                        continue; // already in the user's list
                    }
                    // Added later, a library template is a favourite.
                    self.save_template(library_copy(&entry, false), at, &mut ids)?;
                }
            }
            event::Kind::SetOverride(req) => self.set_override(req, at)?,
            event::Kind::CompleteOnboarding(req) => self.complete_onboarding(req, at, &mut ids)?,
            event::Kind::UpdateSetting(req) => {
                let setting = req
                    .setting
                    .clone()
                    .ok_or_else(|| invalid("setting is required"))?;
                let kind = setting_kind(&setting).ok_or_else(|| invalid("setting is empty"))?;
                self.settings.retain(|s| setting_kind(s) != Some(kind));
                self.settings.push(setting);
            }
            event::Kind::ImportHistory(req) => self.import(req),
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

    // ── Writes ──

    /// A start: the workout, named after its template (or the request), its
    /// sets laid out from the decisions recorded on the event.
    fn start_workout(
        &mut self,
        req: &StartWorkoutRequest,
        workout_id: &str,
        at: i64,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        let started_at = if req.started_at > 0 {
            req.started_at
        } else {
            at
        };
        let name = if !req.name.is_empty() {
            req.name.clone()
        } else if req.template_id.is_empty() {
            "Workout".to_string()
        } else {
            self.template(&req.template_id)
                .ok_or_else(|| CoreError::NotFound("Template not found".into()))?
                .name
                .clone()
        };
        let workout = Workout {
            id: workout_id.to_string(),
            name,
            start_time: started_at,
            template_id: req.template_id.clone(),
            ..Default::default()
        };
        let mut record = WorkoutRecord::new(workout, Vec::new(), Vec::new());
        require_decisions(&record, &req.exercises, &req.decisions)?;
        reducer::apply_add_exercises(&mut record, workout_id, &req.decisions, self.unit(), ids)?;
        self.workouts.push(record);
        self.active_workout_id = workout_id.to_string();
        Ok(())
    }

    /// One change to a workout, through the reducer. The workout is changed
    /// on a copy and put back only if the whole change applied.
    fn mutate_workout(
        &mut self,
        mutation: &WorkoutMutation,
        at: i64,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        let payload = mutation
            .mutation
            .as_ref()
            .ok_or_else(|| invalid("mutation missing"))?;
        let unit = self.unit();
        let index = self
            .workouts
            .iter()
            .position(|r| r.workout.id == mutation_workout_id(payload))
            .ok_or_else(|| CoreError::NotFound("Workout not found".into()))?;
        let mut record = self.workouts[index].clone();
        match payload {
            Mutation::CompleteSet(req) => {
                let mut req = req.clone();
                if req.completed_at <= 0 {
                    req.completed_at = at;
                }
                reducer::apply_complete_set_to_active(&mut record, &req, unit, ids)?;
                // The target may be one the resolution just appended (a
                // rung's `{done_id}:0`), so it is checked after applying.
                if !record
                    .completed_sets
                    .iter()
                    .any(|c| c.proposed_set_id == req.proposed_set_id)
                {
                    return Err(CoreError::FailedPrecondition(
                        "Proposed set not found".into(),
                    ));
                }
            }
            Mutation::StartSet(req) => reducer::apply_start_set_to_active(&mut record, req, at)?,
            Mutation::SkipWarmups(req) => reducer::apply_skip_warmups_to_active(&mut record, req)?,
            Mutation::DeleteCompletedSet(req) => {
                reducer::apply_delete_completed_set_to_active(&mut record, req)?
            }
            Mutation::EndWorkout(req) => {
                // Ending twice changes nothing.
                if record.workout.end_time > 0 {
                    return Ok(());
                }
                record.workout.end_time = if req.ended_at > 0 { req.ended_at } else { at };
                if self.active_workout_id == record.workout.id {
                    self.active_workout_id.clear();
                }
            }
            Mutation::AddExercises(req) => {
                require_decisions(&record, &req.exercises, &req.decisions)?;
                reducer::apply_add_exercises(
                    &mut record,
                    &req.workout_id,
                    &req.decisions,
                    unit,
                    ids,
                )?
            }
            Mutation::AdjustExerciseWeight(req) => {
                reducer::apply_adjust_exercise_weight(&mut record, req, unit, ids, at)?
            }
            Mutation::RemoveExercise(req) => reducer::apply_remove_exercise(&mut record, req)?,
            Mutation::ReorderExercises(req) => reducer::apply_reorder_exercises(&mut record, req)?,
            Mutation::EditCompletedSet(req) => {
                reducer::apply_edit_completed_set_to_active(&mut record, req, unit, at)?
            }
            Mutation::SetSession(req) => record.workout.session_id = req.session_id.clone(),
        }
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
    fn set_override(&mut self, req: &SetOverrideRequest, at: i64) -> Result<(), CoreError> {
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
        req: &CompleteOnboardingRequest,
        at: i64,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        let entries = if req.library_entries.is_empty() && req.library_ids.is_empty() {
            crate::template_library::defaults()
                .into_iter()
                .cloned()
                .collect()
        } else {
            library_entries(&req.library_entries, &req.library_ids)?
        };
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
        for entry in entries {
            self.save_template(library_copy(&entry, true), at, ids)?;
        }
        Ok(())
    }

    fn import(&mut self, req: &ImportHistory) {
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
                heart_rate: imported.heart_rate.clone(),
                exercise_logs: imported.exercise_logs.clone(),
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

/// The workouts an event touches.
pub fn event_workout_ids(event: &Event) -> Vec<String> {
    match &event.kind {
        Some(event::Kind::StartWorkout(_)) => vec![event.id.clone()],
        Some(event::Kind::Workout(WorkoutMutation {
            mutation: Some(mutation),
            ..
        })) => vec![mutation_workout_id(mutation).to_string()],
        Some(event::Kind::HeartRate(req)) => vec![req.workout_id.clone()],
        Some(event::Kind::ImportHistory(req)) => req
            .workouts
            .iter()
            .filter_map(|w| w.workout.as_ref().map(|w| w.id.clone()))
            .collect(),
        _ => Vec::new(),
    }
}

/// The workout a mutation names.
pub fn mutation_workout_id(mutation: &Mutation) -> &str {
    match mutation {
        Mutation::CompleteSet(m) => &m.workout_id,
        Mutation::DeleteCompletedSet(m) => &m.workout_id,
        Mutation::EndWorkout(m) => &m.workout_id,
        Mutation::AddExercises(m) => &m.workout_id,
        Mutation::AdjustExerciseWeight(m) => &m.workout_id,
        Mutation::RemoveExercise(m) => &m.workout_id,
        Mutation::ReorderExercises(m) => &m.workout_id,
        Mutation::EditCompletedSet(m) => &m.workout_id,
        Mutation::StartSet(m) => &m.workout_id,
        Mutation::SkipWarmups(m) => &m.workout_id,
        Mutation::SetSession(m) => &m.workout_id,
    }
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

/// The entries an event adds: as recorded on it, or (events from before
/// they were) looked up by id in the library built in.
fn library_entries(
    recorded: &[LibraryTemplate],
    ids: &[String],
) -> Result<Vec<LibraryTemplate>, CoreError> {
    if !recorded.is_empty() {
        return Ok(recorded.to_vec());
    }
    ids.iter()
        .map(|id| {
            crate::template_library::find(id)
                .cloned()
                .ok_or_else(|| invalid(format!("unknown library template {id:?}")))
        })
        .collect()
}

/// A library entry in the user's list: a new template (empty id, given one
/// and an order on save), coupled to the entry, in rotation or a favourite.
fn library_copy(entry: &LibraryTemplate, in_rotation: bool) -> WorkoutTemplate {
    WorkoutTemplate {
        in_rotation,
        name: entry.name.clone(),
        exercises: entry.exercises.clone(),
        library_id: entry.id.clone(),
        coupled: true,
        ..Default::default()
    }
}
