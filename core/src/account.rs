//! The account: everything one person has recorded, as the fold of their
//! events. `apply` is the only way it changes, and it runs the same on the
//! phone (to show a write now) and on the server (to keep its copy).

use std::collections::BTreeMap;

use crate::exercise_catalog::snap_weight_lb;
use crate::exercise_progress::{
    advance_tracker, calibration_start_weight, resolve_tracker, session_outcomes, TrackerState,
};
use crate::history::WorkoutRecord;
use crate::ids::Ids;
use crate::messages::{
    attachable_briefing_messages_for_workout, build_progression_message,
    session_messages_for_completed_set, slot_key_for_exercise, ProgressionMessage,
};
use crate::pb::{
    event, user_setting, workout_mutation::Mutation, CompleteOnboardingRequest, Event, Exercise,
    ExperienceLevel, Gender, ImportHistory, LibraryTemplate, ProgressionMetricKind,
    ProgressionReasonKind, SetExerciseTrackerRequest, StartWorkoutRequest, TrackerRecord,
    UserMessage, UserMessageKind, UserMessageSurface, UserSetting, WeightUnit, WeightUnitConfig,
    Workout, WorkoutMutation, WorkoutTemplate,
};
use crate::weight_units::{unit_from_proto, AppWeightUnit};
use crate::workout::{self as reducer, ExercisePlan, WorkoutError};

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

/// A coaching message and whether it's been dismissed. Writing a message
/// with the same key replaces it and shows it again.
#[derive(Clone, Debug, PartialEq)]
pub struct StoredMessage {
    pub message: UserMessage,
    pub dismissed: bool,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Account {
    /// The last event folded in; the next one is `seq + 1`.
    pub seq: i64,
    /// At most one per kind.
    pub settings: Vec<UserSetting>,
    /// In the user's order.
    pub templates: Vec<WorkoutTemplate>,
    pub trackers: BTreeMap<i32, TrackerState>,
    /// In the order they were started.
    pub workouts: Vec<WorkoutRecord>,
    /// The workout under way, or empty.
    pub active_workout_id: String,
    pub messages: Vec<StoredMessage>,
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
                let template = req
                    .template
                    .clone()
                    .ok_or_else(|| invalid("template is required"))?;
                self.save_template(template, at, &mut ids)?;
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
                let entries = library_entries(&req.library_ids)?;
                for entry in entries {
                    if self.templates.iter().any(|t| t.library_id == entry.id) {
                        continue; // already in the user's list
                    }
                    self.save_template(library_copy(entry), at, &mut ids)?;
                }
            }
            event::Kind::SetExerciseTracker(req) => self.set_tracker(req)?,
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
            event::Kind::DismissUserMessages(req) => {
                for stored in &mut self.messages {
                    if req.message_keys.contains(&stored.message.message_key) {
                        stored.dismissed = true;
                    }
                }
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

    /// Resolve exercises into plans: weights from the trackers, sets/reps/
    /// rest from the prescription, and the layoff deload applied here only
    /// (never written back — it sticks only once the user trains). A loaded
    /// exercise never performed gets a calibration plan instead: one rung
    /// at the ramp start.
    fn exercise_plans(&self, exercises: &[i32], now: i64) -> Vec<ExercisePlan> {
        let unit = self.unit();
        exercises
            .iter()
            .filter_map(|value| {
                let exercise = Exercise::try_from(*value).ok()?;
                if exercise == Exercise::Unspecified {
                    return None;
                }
                let state = self.trackers.get(value);
                let resolved = resolve_tracker(exercise, state, unit);
                let calibration = calibration_start_weight(exercise, state, unit);
                let weight = match calibration {
                    Some(ramp_start) => ramp_start,
                    None => layoff_adjusted_weight(
                        exercise,
                        resolved.working_weight,
                        resolved.last_performed_at,
                        now,
                        unit,
                    ),
                };
                Some(ExercisePlan {
                    exercise: *value,
                    working_weight: weight,
                    sets: resolved.sets,
                    reps: resolved.target_reps,
                    rest_success: resolved.rest_seconds,
                    rest_failure: resolved.rest_seconds_failure,
                    include_warmup: resolved.include_warmup,
                    calibration: calibration.is_some(),
                })
            })
            .collect()
    }

    // ── Writes ──

    /// A start is resolved here: weights from the trackers, sets/reps/rest
    /// from the prescription. The request names a template, an exercise
    /// list, or nothing (an empty workout). Briefing messages about its
    /// exercises are attached to it.
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
        let (exercises, name) = if req.template_id.is_empty() {
            (req.exercises.clone(), "Workout".to_string())
        } else {
            let template = self
                .template(&req.template_id)
                .ok_or_else(|| CoreError::NotFound("Template not found".into()))?;
            (template.exercises.clone(), template.name.clone())
        };
        let name = if req.name.is_empty() {
            name
        } else {
            req.name.clone()
        };
        let plans = self.exercise_plans(&exercises, started_at);
        let workout = Workout {
            id: workout_id.to_string(),
            name,
            start_time: started_at,
            template_id: req.template_id.clone(),
            ..Default::default()
        };
        let mut record = WorkoutRecord::new(workout, Vec::new(), Vec::new());
        reducer::apply_add_exercises(&mut record, workout_id, &plans, self.unit(), ids)?;

        let pending = self.pending_briefing_messages();
        let planned: Vec<i32> = plans.iter().map(|p| p.exercise).collect();
        for key in attachable_briefing_messages_for_workout(&pending, &planned) {
            if let Some(stored) = self
                .messages
                .iter_mut()
                .find(|m| m.message.message_key == key)
            {
                // Tied to this workout so it shows for the whole session.
                stored.message.workout_id = workout_id.to_string();
                stored.message.source_workout_id = workout_id.to_string();
                stored.message.updated_at = started_at;
            }
        }
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
        let mut new_messages = Vec::new();
        let mut ended = false;
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
                if let Some(proposed) = record
                    .proposed_sets
                    .iter()
                    .find(|s| s.id == req.proposed_set_id)
                {
                    new_messages.extend(session_messages_for_completed_set(
                        &req.workout_id,
                        proposed,
                        req.actual_reps,
                        req.completed_at,
                    ));
                }
            }
            Mutation::StartSet(req) => reducer::apply_start_set_to_active(&mut record, req, at)?,
            Mutation::SkipWarmups(req) => reducer::apply_skip_warmups_to_active(&mut record, req)?,
            Mutation::DeleteCompletedSet(req) => {
                reducer::apply_delete_completed_set_to_active(&mut record, req)?
            }
            Mutation::EndWorkout(req) => {
                // Ending twice changes nothing: progression runs once.
                if record.workout.end_time > 0 {
                    return Ok(());
                }
                record.workout.end_time = if req.ended_at > 0 { req.ended_at } else { at };
                // Every open "how was that" closes as "right" before
                // progression reads the efforts.
                reducer::resolve_all_effort(&mut record);
                ended = true;
            }
            Mutation::AddExercises(req) => {
                let plans = self.exercise_plans(&req.exercises, at);
                reducer::apply_add_exercises(&mut record, &req.workout_id, &plans, unit, ids)?
            }
            Mutation::AdjustExerciseWeight(req) => {
                reducer::apply_adjust_exercise_weight(&mut record, req, unit, ids)?
            }
            Mutation::RemoveExercise(req) => reducer::apply_remove_exercise(&mut record, req)?,
            Mutation::ReorderExercises(req) => reducer::apply_reorder_exercises(&mut record, req)?,
            Mutation::RateExercise(req) => {
                reducer::apply_rate_exercise_to_active(&mut record, req, unit)?
            }
            Mutation::EditCompletedSet(req) => {
                reducer::apply_edit_completed_set_to_active(&mut record, req, unit)?
            }
        }
        if ended {
            new_messages.extend(self.advance_trackers(&record, at));
            if self.active_workout_id == record.workout.id {
                self.active_workout_id.clear();
            }
        }
        self.workouts[index] = record;
        self.put_messages(new_messages);
        Ok(())
    }

    /// Advance every tracker a finished workout touched — the single seam
    /// where performance becomes prescription. Returns the progression
    /// messages saying what changed.
    fn advance_trackers(&mut self, record: &WorkoutRecord, at: i64) -> Vec<UserMessage> {
        let unit = self.unit();
        let mut outcomes: Vec<_> = session_outcomes(record).into_iter().collect();
        outcomes.sort_by_key(|(exercise, _)| *exercise);
        let mut messages = Vec::new();
        for (value, outcome) in outcomes {
            let Ok(exercise) = Exercise::try_from(value) else {
                continue;
            };
            if exercise == Exercise::Unspecified {
                continue;
            }
            let before = self.trackers.get(&value).copied().unwrap_or_default();
            let after = advance_tracker(exercise, &before, &outcome, unit);
            self.trackers.insert(value, after);
            messages.extend(progression_message_for_change(
                exercise,
                outcome.performed_weight,
                &after,
                &record.workout.id,
                at,
            ));
        }
        messages
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

    /// A manual correction: the weight, the rep target (0 restarts the climb
    /// at the range bottom) and the overrides. The miss and hard streaks
    /// start again.
    fn set_tracker(&mut self, req: &SetExerciseTrackerRequest) -> Result<(), CoreError> {
        let exercise = Exercise::try_from(req.exercise)
            .ok()
            .filter(|ex| *ex != Exercise::Unspecified)
            .ok_or_else(|| invalid("Unknown exercise"))?;
        if req.override_rep_low > 0 && req.override_rep_high < req.override_rep_low {
            return Err(invalid("The rep range top must be at or above the bottom"));
        }
        let previous = self
            .trackers
            .get(&req.exercise)
            .copied()
            .unwrap_or_default();
        let state = TrackerState {
            working_weight: snap_weight_lb(exercise, req.working_weight.max(0.0), self.unit()),
            current_reps: req.target_reps.clamp(0, 100),
            consecutive_misses: 0,
            last_performed_at: previous.last_performed_at,
            override_sets: req.override_sets.max(0),
            override_rep_low: req.override_rep_low.max(0),
            override_rep_high: req.override_rep_high.max(0),
            consecutive_hard: 0,
        };
        self.trackers.insert(req.exercise, state);
        Ok(())
    }

    /// The unit always; then, the first time only (no templates yet):
    /// trackers for the main lifts from the strength slider (or the older
    /// bodyweight/experience answers), and the library entries ticked (the
    /// defaults when none are named).
    fn complete_onboarding(
        &mut self,
        req: &CompleteOnboardingRequest,
        at: i64,
        ids: &mut Ids,
    ) -> Result<(), CoreError> {
        let entries = if req.library_ids.is_empty() {
            crate::template_library::defaults()
        } else {
            library_entries(&req.library_ids)?
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
        let unit = unit_from_proto(req.unit);
        let seeds = match req.strength {
            Some(strength) => {
                crate::onboarding::starting_tracker_weights_for_strength(strength, unit)
            }
            None => crate::onboarding::starting_tracker_weights(
                req.body_weight_kg,
                ExperienceLevel::try_from(req.experience).unwrap_or(ExperienceLevel::Unspecified),
                Gender::try_from(req.gender).unwrap_or(Gender::Unspecified),
                unit,
            ),
        };
        for (exercise, weight) in seeds {
            self.trackers
                .entry(exercise as i32)
                .or_insert_with(|| TrackerState {
                    working_weight: weight,
                    ..Default::default()
                });
        }
        for entry in entries {
            self.save_template(library_copy(entry), at, ids)?;
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
            });
        }
        self.workouts.sort_by_key(|r| r.workout.start_time);
        for tracker in &req.trackers {
            self.trackers
                .insert(tracker.exercise, tracker_state(tracker));
        }
    }

    // ── Messages ──

    fn put_messages(&mut self, messages: Vec<UserMessage>) {
        for message in messages {
            let stored = StoredMessage {
                message,
                dismissed: false,
            };
            match self
                .messages
                .iter_mut()
                .find(|m| m.message.message_key == stored.message.message_key)
            {
                Some(existing) => *existing = stored,
                None => self.messages.push(stored),
            }
        }
    }

    /// Briefing messages not yet tied to a workout or dismissed, newest first.
    pub fn pending_briefing_messages(&self) -> Vec<UserMessage> {
        let mut out: Vec<UserMessage> = self
            .messages
            .iter()
            .filter(|m| {
                !m.dismissed
                    && m.message.workout_id.is_empty()
                    && m.message.surface == UserMessageSurface::WorkoutBriefing as i32
            })
            .map(|m| m.message.clone())
            .collect();
        out.sort_by_key(|m| std::cmp::Reverse(m.updated_at));
        out
    }

    /// The messages about one workout that are still showing, newest first.
    pub fn workout_messages(&self, workout_id: &str) -> Vec<UserMessage> {
        let mut out: Vec<UserMessage> = self
            .messages
            .iter()
            .filter(|m| !m.dismissed && m.message.source_workout_id == workout_id)
            .map(|m| m.message.clone())
            .collect();
        out.sort_by_key(|m| std::cmp::Reverse(m.updated_at));
        out
    }
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
        Mutation::RateExercise(m) => &m.workout_id,
        Mutation::EditCompletedSet(m) => &m.workout_id,
        Mutation::StartSet(m) => &m.workout_id,
        Mutation::SkipWarmups(m) => &m.workout_id,
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

fn library_entries(ids: &[String]) -> Result<Vec<&'static LibraryTemplate>, CoreError> {
    ids.iter()
        .map(|id| {
            crate::template_library::find(id)
                .ok_or_else(|| invalid(format!("unknown library template {id:?}")))
        })
        .collect()
}

/// A user's copy of a library entry: a new template (empty id, given one
/// and an order on save) that remembers where it came from.
fn library_copy(entry: &LibraryTemplate) -> WorkoutTemplate {
    WorkoutTemplate {
        name: entry.name.clone(),
        exercises: entry.exercises.clone(),
        library_id: entry.id.clone(),
        ..Default::default()
    }
}

pub fn tracker_state(record: &TrackerRecord) -> TrackerState {
    TrackerState {
        working_weight: record.working_weight,
        current_reps: record.current_reps,
        consecutive_misses: record.consecutive_misses,
        last_performed_at: record.last_performed_at,
        override_sets: record.override_sets,
        override_rep_low: record.override_rep_low,
        override_rep_high: record.override_rep_high,
        consecutive_hard: record.consecutive_hard,
    }
}

pub fn tracker_record(exercise: i32, state: &TrackerState) -> TrackerRecord {
    TrackerRecord {
        exercise,
        working_weight: state.working_weight,
        current_reps: state.current_reps,
        consecutive_misses: state.consecutive_misses,
        last_performed_at: state.last_performed_at,
        override_sets: state.override_sets,
        override_rep_low: state.override_rep_low,
        override_rep_high: state.override_rep_high,
        consecutive_hard: state.consecutive_hard,
    }
}

/// The layoff deload: 90% after 14 days away from this exercise, 80% after
/// 30, snapped loadable. Applied when planning only — the tracker is never
/// written here, so the reduction sticks only when the user performs the
/// reduced session (progression follows performed weight).
fn layoff_adjusted_weight(
    exercise: Exercise,
    weight: f32,
    last_performed_at: i64,
    now: i64,
    unit: AppWeightUnit,
) -> f32 {
    if last_performed_at <= 0 || weight <= 0.0 {
        return weight;
    }
    let days = (now - last_performed_at) / (24 * 3600);
    let factor = if days >= 30 {
        0.8
    } else if days >= 14 {
        0.9
    } else {
        return weight;
    };
    snap_weight_lb(exercise, weight * factor, unit)
}

/// One progression card per exercise per workout: what you lifted and
/// what the tracker says next time. Weight moves name the delta; a hold
/// stays quiet (a "nothing changed" card for every exercise every session
/// would be noise).
fn progression_message_for_change(
    exercise: Exercise,
    performed_weight: f32,
    after: &TrackerState,
    workout_id: &str,
    at: i64,
) -> Option<UserMessage> {
    if performed_weight <= 0.0 {
        return None;
    }
    let next = after.working_weight;
    let slot_key = slot_key_for_exercise(exercise);
    let (kind, reason_kind) = if next > performed_weight + 0.1 {
        (
            UserMessageKind::LoadIncrease,
            ProgressionReasonKind::CompletedAllWorkingSets,
        )
    } else if next < performed_weight - 0.1 {
        (
            UserMessageKind::StallDeload,
            ProgressionReasonKind::RepeatedMisses,
        )
    } else {
        return None;
    };
    Some(build_progression_message(ProgressionMessage {
        key: format!("pending:{workout_id}:{}:{slot_key}", kind.as_str_name()),
        kind,
        exercise,
        slot_key,
        source_workout_id: workout_id,
        previous_weight: performed_weight,
        next_weight: next,
        metric_kind: ProgressionMetricKind::WorkingWeight,
        reason_kind,
        now: at,
        ..Default::default()
    }))
}
