//! The account's API: the app's RPCs, answered from an `Account`. A write
//! records an event (or a few) and answers from the account after it; a read
//! only looks. The phone calls these through [`call`] with the request's
//! proto bytes, so the app keeps its generated request and response types.

use std::collections::HashMap;

use prost::Message;

use crate::account::{Account, CoreError};
use crate::exercise_catalog::{
    all_exercises, category, load_style, muscle_key, muscle_label, primary_muscle,
};
use crate::exercise_progress::{resolve_tracker, weight_history};
use crate::history::WorkoutRecord;
use crate::ids::derived_id;
use crate::pb::*;
use crate::progress::{compute_exercise_progress, compute_next_up_set, compute_workout_summary};
use crate::recovery::per_muscle_recovery;
use crate::volume::{muscle_volume_7d, suggest_template};
use crate::workout::{
    active_proposed_sets, get_workout_response_from_active, start_workout_response_from_active,
    workout_state_snapshot,
};

/// One call into the account: the time it's made, and the id the first
/// event it records takes (later ones derive from it).
pub struct Call<'a> {
    pub account: &'a mut Account,
    pub now: i64,
    pub event_id: String,
    /// What this call recorded, for the host to store and sync.
    pub events: Vec<Event>,
    /// The template library coupled templates follow.
    pub library: &'a [LibraryTemplate],
}

impl<'a> Call<'a> {
    pub fn view(&self) -> View<'_> {
        View::new(self.account, self.now).with_library(self.library)
    }

    pub fn new(account: &'a mut Account, now: i64, event_id: impl Into<String>) -> Self {
        Self {
            account,
            now,
            event_id: event_id.into(),
            events: Vec::new(),
            library: crate::template_library::library(),
        }
    }

    /// Follow [library] (the server's) instead of the one built in.
    pub fn with_library(mut self, library: &'a [LibraryTemplate]) -> Self {
        self.library = library;
        self
    }

    /// The library entries for [ids], as they are now.
    fn library_entries(&self, ids: &[String]) -> Result<Vec<LibraryTemplate>, CoreError> {
        ids.iter()
            .map(|id| {
                self.library
                    .iter()
                    .find(|e| &e.id == id)
                    .cloned()
                    .ok_or_else(|| {
                        CoreError::InvalidArgument(format!("unknown library template {id:?}"))
                    })
            })
            .collect()
    }

    /// Record one event: applied to the account and kept, or (on an error)
    /// neither. Returns the event's id.
    fn record(&mut self, kind: event::Kind) -> Result<String, CoreError> {
        let id = match self.events.len() {
            0 => self.event_id.clone(),
            n => derived_id(&self.event_id, n),
        };
        let event = Event {
            seq: self.account.seq + 1,
            id: id.clone(),
            at: self.now,
            kind: Some(kind),
        };
        self.account.apply(&event)?;
        self.account.seq = event.seq;
        self.events.push(event);
        Ok(id)
    }

    fn mutate(&mut self, mutation: workout_mutation::Mutation) -> Result<String, CoreError> {
        self.record(event::Kind::Workout(WorkoutMutation {
            mutation: Some(mutation),
            ..Default::default()
        }))
    }

    // ── Workouts ──

    pub fn start_workout(
        &mut self,
        mut req: StartWorkoutRequest,
    ) -> Result<StartWorkoutResponse, CoreError> {
        // A coupled template starts with the library's exercises of now,
        // recorded on the event.
        if req.exercises.is_empty() {
            if let Some(template) = self.account.template(&req.template_id) {
                req.exercises = self.view().resolved(template).exercises;
            }
        }
        let id = self.record(event::Kind::StartWorkout(req))?;
        let mut response = start_workout_response_from_active(self.view().workout(&id)?, self.now);
        response.user_messages = self.account.workout_messages(&id);
        Ok(response)
    }

    pub fn end_workout(&mut self, req: EndWorkoutRequest) -> Result<EndWorkoutResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::EndWorkout(req))?;
        let progression = format!("pending:{id}:");
        Ok(EndWorkoutResponse {
            workout: Some(self.view().workout(&id)?.workout.clone()),
            user_messages: self
                .account
                .workout_messages(&id)
                .into_iter()
                .filter(|m| m.message_key.starts_with(&progression))
                .collect(),
        })
    }

    pub fn complete_set(
        &mut self,
        req: CompleteSetRequest,
    ) -> Result<CompleteSetResponse, CoreError> {
        let (workout_id, proposed_set_id) = (req.workout_id.clone(), req.proposed_set_id.clone());
        self.mutate(workout_mutation::Mutation::CompleteSet(req))?;
        let state = self.view().workout_response(&workout_id)?;
        Ok(CompleteSetResponse {
            completed_set: state
                .completed_sets
                .iter()
                .filter(|c| c.proposed_set_id == proposed_set_id)
                .max_by_key(|c| c.ended_at)
                .cloned(),
            next_up_set: state.next_up_set,
            state_snapshot: state.state_snapshot,
            user_messages: state.user_messages,
        })
    }

    pub fn delete_completed_set(
        &mut self,
        req: DeleteCompletedSetRequest,
    ) -> Result<DeleteCompletedSetResponse, CoreError> {
        let workout_id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::DeleteCompletedSet(req))?;
        let state = self.view().workout_response(&workout_id)?;
        Ok(DeleteCompletedSetResponse {
            next_up_set: state.next_up_set,
            state_snapshot: state.state_snapshot,
            user_messages: state.user_messages,
        })
    }

    pub fn add_exercises(
        &mut self,
        req: AddExercisesRequest,
    ) -> Result<WorkoutPlanResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::AddExercises(req))?;
        self.view().plan_response(&id)
    }

    pub fn adjust_exercise_weight(
        &mut self,
        req: AdjustExerciseWeightRequest,
    ) -> Result<WorkoutPlanResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::AdjustExerciseWeight(req))?;
        self.view().plan_response(&id)
    }

    pub fn remove_exercise(
        &mut self,
        req: RemoveExerciseRequest,
    ) -> Result<WorkoutPlanResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::RemoveExercise(req))?;
        self.view().plan_response(&id)
    }

    pub fn reorder_exercises(
        &mut self,
        req: ReorderExercisesRequest,
    ) -> Result<WorkoutPlanResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::ReorderExercises(req))?;
        self.view().plan_response(&id)
    }

    /// Several changes in one go (the watch's intents arrive this way). One
    /// that can't apply — a set already gone, a workout already over — is
    /// skipped and the rest still apply.
    pub fn append_workout_mutations(
        &mut self,
        req: AppendWorkoutMutationsRequest,
    ) -> Result<AppendWorkoutMutationsResponse, CoreError> {
        let mut workout_id = None;
        let mut applied = Vec::with_capacity(req.mutations.len());
        for mutation in req.mutations {
            let payload = mutation
                .mutation
                .ok_or_else(|| CoreError::InvalidArgument("mutation missing".into()))?;
            workout_id
                .get_or_insert_with(|| crate::account::mutation_workout_id(&payload).to_string());
            let _ = self.mutate(payload);
            applied.push(mutation.event_id);
        }
        Ok(AppendWorkoutMutationsResponse {
            applied_event_ids: applied,
            workout_state: match workout_id {
                Some(id) => self.view().workout_response(&id).ok(),
                None => None,
            },
        })
    }

    pub fn append_workout_heart_rate(
        &mut self,
        req: AppendWorkoutHeartRateRequest,
    ) -> Result<AppendWorkoutHeartRateResponse, CoreError> {
        let stored = req.samples.len() as i32;
        self.record(event::Kind::HeartRate(req))?;
        Ok(AppendWorkoutHeartRateResponse { stored })
    }

    // ── Home, templates, trackers ──

    pub fn save_template(
        &mut self,
        req: SaveTemplateRequest,
    ) -> Result<SaveTemplateResponse, CoreError> {
        let given = req
            .template
            .as_ref()
            .map(|t| t.id.clone())
            .unwrap_or_default();
        // Saving a coupled template as the library has it changes nothing.
        if let (Some(existing), Some(saved)) = (self.account.template(&given), &req.template) {
            let shown = self.view().resolved(existing);
            if existing.coupled && shown.name == saved.name && shown.exercises == saved.exercises {
                return Ok(SaveTemplateResponse {
                    template: Some(shown),
                });
            }
        }
        let event_id = self.record(event::Kind::SaveTemplate(req))?;
        // A new template takes the event's first derived id.
        let id = if given.is_empty() {
            derived_id(&event_id, 0)
        } else {
            given
        };
        Ok(SaveTemplateResponse {
            template: self.account.template(&id).cloned(),
        })
    }

    pub fn clone_template(
        &mut self,
        mut req: CloneTemplateRequest,
    ) -> Result<CloneTemplateResponse, CoreError> {
        let template = self
            .account
            .template(&req.template_id)
            .ok_or_else(|| CoreError::NotFound("Template not found".into()))?;
        let shown = self.view().resolved(template);
        req.name = shown.name;
        req.exercises = shown.exercises;
        let id = req.template_id.clone();
        self.record(event::Kind::CloneTemplate(req))?;
        Ok(CloneTemplateResponse {
            template: self.account.template(&id).cloned(),
        })
    }

    pub fn delete_template(
        &mut self,
        req: DeleteTemplateRequest,
    ) -> Result<DeleteTemplateResponse, CoreError> {
        self.record(event::Kind::DeleteTemplate(req))?;
        Ok(DeleteTemplateResponse {})
    }

    pub fn reorder_templates(
        &mut self,
        req: ReorderTemplatesRequest,
    ) -> Result<ReorderTemplatesResponse, CoreError> {
        self.record(event::Kind::ReorderTemplates(req))?;
        Ok(ReorderTemplatesResponse {})
    }

    pub fn set_exercise_tracker(
        &mut self,
        req: SetExerciseTrackerRequest,
    ) -> Result<SetExerciseTrackerResponse, CoreError> {
        let exercise = req.exercise();
        self.record(event::Kind::SetExerciseTracker(req))?;
        Ok(SetExerciseTrackerResponse {
            tracker: Some(self.view().tracker(exercise, Vec::new())),
        })
    }

    pub fn complete_onboarding(
        &mut self,
        mut req: CompleteOnboardingRequest,
    ) -> Result<CompleteOnboardingResponse, CoreError> {
        req.library_entries = if req.library_ids.is_empty() {
            self.library
                .iter()
                .filter(|e| e.is_default)
                .cloned()
                .collect()
        } else {
            self.library_entries(&req.library_ids)?
        };
        self.record(event::Kind::CompleteOnboarding(req))?;
        Ok(CompleteOnboardingResponse {
            home: Some(self.view().get_home()),
        })
    }

    pub fn add_library_templates(
        &mut self,
        mut req: AddLibraryTemplatesRequest,
    ) -> Result<AddLibraryTemplatesResponse, CoreError> {
        req.entries = self.library_entries(&req.library_ids)?;
        self.record(event::Kind::AddLibraryTemplates(req))?;
        Ok(AddLibraryTemplatesResponse {
            home: Some(self.view().get_home()),
        })
    }

    pub fn dismiss_user_messages(
        &mut self,
        req: DismissUserMessagesRequest,
    ) -> Result<DismissUserMessagesResponse, CoreError> {
        let showing: Vec<String> = req
            .message_keys
            .iter()
            .filter(|key| {
                self.account
                    .messages
                    .iter()
                    .any(|m| !m.dismissed && &&m.message.message_key == key)
            })
            .cloned()
            .collect();
        if !showing.is_empty() {
            self.record(event::Kind::DismissUserMessages(req))?;
        }
        Ok(DismissUserMessagesResponse {
            dismissed_message_keys: showing,
        })
    }

    /// Bring in history from elsewhere as it was (an account moving here).
    pub fn import_history(
        &mut self,
        req: ImportHistory,
    ) -> Result<ImportHistoryResponse, CoreError> {
        self.record(event::Kind::ImportHistory(req))?;
        Ok(ImportHistoryResponse {})
    }

    // ── Settings ──

    pub fn update_setting(
        &mut self,
        req: UpdateSettingRequest,
    ) -> Result<UpdateSettingResponse, CoreError> {
        self.record(event::Kind::UpdateSetting(req))?;
        Ok(UpdateSettingResponse {})
    }
}

/// The account, read: every query the app makes. Nothing here changes it.
#[derive(Clone, Copy)]
pub struct View<'a> {
    pub account: &'a Account,
    pub now: i64,
    /// The template library coupled templates follow.
    pub library: &'a [LibraryTemplate],
}

impl<'a> View<'a> {
    pub fn new(account: &'a Account, now: i64) -> Self {
        Self {
            account,
            now,
            library: crate::template_library::library(),
        }
    }

    /// Follow [library] (the server's) instead of the one built in.
    pub fn with_library(mut self, library: &'a [LibraryTemplate]) -> Self {
        self.library = library;
        self
    }

    /// A template as it's shown and started: a coupled one takes its
    /// library entry's name and exercises, while the entry exists.
    pub fn resolved(&self, template: &WorkoutTemplate) -> WorkoutTemplate {
        let mut out = template.clone();
        if let Some(entry) = self
            .library
            .iter()
            .find(|e| template.coupled && e.id == template.library_id)
        {
            out.name = entry.name.clone();
            out.exercises = entry.exercises.clone();
        }
        out
    }

    fn workout(&self, id: &str) -> Result<&'a WorkoutRecord, CoreError> {
        self.account
            .workout(id)
            .ok_or_else(|| CoreError::NotFound("Workout not found".into()))
    }

    /// A workout as the app shows it: visible sets, its messages.
    pub fn workout_response(&self, id: &str) -> Result<GetWorkoutResponse, CoreError> {
        let record = self.workout(id)?;
        let mut response = get_workout_response_from_active(record, self.now);
        // Cancelled rows mark a bailed exercise for progression; the app
        // never shows them.
        response.proposed_sets.retain(|s| !s.cancelled);
        response.user_messages = self.account.workout_messages(id);
        Ok(response)
    }

    pub fn plan_response(&self, id: &str) -> Result<WorkoutPlanResponse, CoreError> {
        let record = self.workout(id)?;
        let visible = active_proposed_sets(&record.proposed_sets);
        Ok(WorkoutPlanResponse {
            next_up_set: compute_next_up_set(&visible, &record.completed_sets),
            proposed_sets: visible,
            state_snapshot: Some(workout_state_snapshot(
                &record.workout,
                &record.proposed_sets,
                &record.completed_sets,
                self.now,
            )),
        })
    }

    pub fn get_workout(&self, req: GetWorkoutRequest) -> Result<GetWorkoutResponse, CoreError> {
        self.workout_response(&req.workout_id)
    }

    pub fn get_active_workout(&self) -> GetActiveWorkoutResponse {
        GetActiveWorkoutResponse {
            workout: self.account.active_workout().map(|r| r.workout.clone()),
        }
    }

    /// Finished workouts, newest first.
    pub fn finished(&self) -> Vec<&'a WorkoutRecord> {
        let mut out: Vec<&WorkoutRecord> = self
            .account
            .workouts
            .iter()
            .filter(|r| r.workout.end_time > 0)
            .collect();
        out.sort_by_key(|r| std::cmp::Reverse(r.workout.start_time));
        out
    }

    pub fn list_workouts(&self) -> ListWorkoutsResponse {
        ListWorkoutsResponse {
            workouts: self
                .finished()
                .into_iter()
                .map(|r| r.workout.clone())
                .collect(),
        }
    }

    pub fn list_workout_summaries(&self) -> ListWorkoutSummariesResponse {
        ListWorkoutSummariesResponse {
            workouts: self
                .finished()
                .into_iter()
                .map(|r| WorkoutWithSummary {
                    summary: Some(compute_workout_summary(
                        &r.workout,
                        &r.proposed_sets,
                        &r.completed_sets,
                    )),
                    workout: Some(r.workout.clone()),
                })
                .collect(),
        }
    }

    pub fn get_exercise_progress(&self) -> GetExerciseProgressResponse {
        let finished = self.finished();
        GetExerciseProgressResponse {
            workout_count: finished.len() as i32,
            since: finished
                .iter()
                .map(|r| r.workout.start_time)
                .min()
                .unwrap_or(0),
            total_volume: finished
                .iter()
                .map(|r| {
                    compute_workout_summary(&r.workout, &r.proposed_sets, &r.completed_sets)
                        .total_volume
                })
                .sum(),
            exercises: compute_exercise_progress(&finished),
        }
    }

    pub fn get_workout_heart_rate(
        &self,
        req: GetWorkoutHeartRateRequest,
    ) -> Result<GetWorkoutHeartRateResponse, CoreError> {
        let mut samples = self.workout(&req.workout_id)?.heart_rate.clone();
        samples.sort_by_key(|s| s.sampled_at);
        Ok(GetWorkoutHeartRateResponse { samples })
    }

    /// One exercise's tracker, resolved: what the next workout will use.
    pub fn tracker(&self, exercise: Exercise, weight_history: Vec<f32>) -> ExerciseTracker {
        let value = exercise as i32;
        let resolved = resolve_tracker(
            exercise,
            self.account.trackers.get(&value),
            self.account.unit(),
        );
        ExerciseTracker {
            exercise: value,
            working_weight: resolved.working_weight,
            sets: resolved.sets,
            target_reps: resolved.target_reps,
            rep_range_low: resolved.rep_low,
            rep_range_high: resolved.rep_high,
            rest_seconds: resolved.rest_seconds,
            rest_seconds_failure: resolved.rest_seconds_failure,
            include_warmup: resolved.include_warmup,
            last_performed_at: resolved.last_performed_at,
            weight_history,
            overridden: resolved.overridden,
            primary_muscle: primary_muscle(exercise) as i32,
            category: category(exercise) as i32,
            equipment: load_style(exercise).to_proto() as i32,
        }
    }

    /// Everything the home screen needs, in one response.
    pub fn get_home(&self) -> GetHomeResponse {
        // Volume needs 7 days and recovery the latest session per muscle; a
        // fixed number of recent workouts keeps the work flat as history
        // grows.
        const RECENT: usize = 24;
        let mut recent: Vec<WorkoutRecord> = self.account.workouts.clone();
        recent.sort_by_key(|r| std::cmp::Reverse(r.workout.start_time));
        recent.truncate(RECENT);

        let history_series = weight_history(&recent);
        let trackers = all_exercises()
            .into_iter()
            .map(|exercise| {
                let series = history_series
                    .get(&(exercise as i32))
                    .cloned()
                    .unwrap_or_default();
                self.tracker(exercise, series)
            })
            .collect();
        let volume = muscle_volume_7d(&recent, self.now);
        let recovery = per_muscle_recovery(&recent, self.now)
            .into_iter()
            .map(|entry| MuscleRecoveryStatus {
                muscle_key: muscle_key(entry.muscle).to_string(),
                label: muscle_label(entry.muscle).to_string(),
                last_trained_at: entry.last_trained_at,
                recovered_at: entry.recovered_at,
                fraction: entry.fraction,
                hours_remaining: entry.hours_remaining(self.now),
                recovered: entry.is_recovered(self.now),
            })
            .collect();

        let mut last_started: HashMap<String, i64> = HashMap::new();
        for r in &self.account.workouts {
            if !r.workout.template_id.is_empty() {
                let at = last_started
                    .entry(r.workout.template_id.clone())
                    .or_default();
                *at = (*at).max(r.workout.start_time);
            }
        }
        let templates: Vec<WorkoutTemplate> = self
            .account
            .templates
            .iter()
            .map(|t| self.resolved(t))
            .collect();
        let (suggested_template_id, suggestion_reason) =
            suggest_template(&templates, &volume, &last_started).unwrap_or_default();

        GetHomeResponse {
            onboarded: !templates.is_empty() || !self.account.workouts.is_empty(),
            templates,
            trackers,
            active_workout_id: self.account.active_workout_id.clone(),
            user_messages: self.account.pending_briefing_messages(),
            volume,
            recovery,
            suggested_template_id,
            suggestion_reason,
        }
    }

    pub fn get_starting_weights(
        &self,
        req: GetStartingWeightsRequest,
    ) -> Result<GetStartingWeightsResponse, CoreError> {
        let unit = crate::weight_units::unit_from_proto(req.unit);
        let steps = (0..=100)
            .map(|step| StartingWeightsStep {
                weights: crate::onboarding::starting_tracker_weights_for_strength(
                    step as f32 / 100.0,
                    unit,
                )
                .into_iter()
                .map(|(exercise, weight_lb)| ExerciseWeight {
                    exercise: exercise as i32,
                    weight_lb,
                })
                .collect(),
            })
            .collect();
        Ok(GetStartingWeightsResponse { steps })
    }

    pub fn list_template_library(&self) -> ListTemplateLibraryResponse {
        ListTemplateLibraryResponse {
            templates: self.library.to_vec(),
        }
    }

    pub fn get_settings(&self) -> GetSettingsResponse {
        GetSettingsResponse {
            settings: self.account.settings.clone(),
        }
    }
}

/// Answer one RPC by name, request and response as proto bytes. Methods are
/// the gRPC method names (`"StartWorkout"`, `"GetHome"`, …).
pub fn call(call: &mut Call, method: &str, request: &[u8]) -> Result<Vec<u8>, CoreError> {
    fn decode<T: Message + Default>(bytes: &[u8]) -> Result<T, CoreError> {
        T::decode(bytes).map_err(|e| CoreError::InvalidArgument(format!("bad request: {e}")))
    }
    macro_rules! routes {
        (
            writes { $($w:literal => $wf:ident,)* }
            reads { $($r:literal => $rf:ident,)* }
            plain { $($p:literal => $pf:ident,)* }
        ) => {
            match method {
                $($w => call.$wf(decode(request)?)?.encode_to_vec(),)*
                $($r => call.view().$rf(decode(request)?)?.encode_to_vec(),)*
                $($p => call.view().$pf().encode_to_vec(),)*
                _ => return Err(CoreError::InvalidArgument(format!("unknown method {method:?}"))),
            }
        };
    }
    Ok(routes! {
        writes {
            "StartWorkout" => start_workout,
            "EndWorkout" => end_workout,
            "CompleteSet" => complete_set,
            "DeleteCompletedSet" => delete_completed_set,
            "AddExercises" => add_exercises,
            "AdjustExerciseWeight" => adjust_exercise_weight,
            "RemoveExercise" => remove_exercise,
            "ReorderExercises" => reorder_exercises,
            "AppendWorkoutMutations" => append_workout_mutations,
            "AppendWorkoutHeartRate" => append_workout_heart_rate,
            "SaveTemplate" => save_template,
            "DeleteTemplate" => delete_template,
            "ReorderTemplates" => reorder_templates,
            "SetExerciseTracker" => set_exercise_tracker,
            "CompleteOnboarding" => complete_onboarding,
            "AddLibraryTemplates" => add_library_templates,
            "CloneTemplate" => clone_template,
            "DismissUserMessages" => dismiss_user_messages,
            "UpdateSetting" => update_setting,
            "ImportHistory" => import_history,
        }
        reads {
            "GetWorkout" => get_workout,
            "GetWorkoutHeartRate" => get_workout_heart_rate,
            "GetStartingWeights" => get_starting_weights,
        }
        plain {
            "GetActiveWorkout" => get_active_workout,
            "ListWorkouts" => list_workouts,
            "ListWorkoutSummaries" => list_workout_summaries,
            "GetExerciseProgress" => get_exercise_progress,
            "GetHome" => get_home,
            "ListTemplateLibrary" => list_template_library,
            "GetSettings" => get_settings,
        }
    })
}
