//! The account's API: the app's RPCs, answered from an `Account`. A write
//! records an event (or a few) and answers from the account after it; a read
//! only looks. The phone calls these through [`call`] with the request's
//! proto bytes, so the app keeps its generated request and response types.

use std::collections::HashMap;

use prost::Message;

use crate::account::{Account, CoreError};
use crate::exercise_catalog::{all_exercises, muscle_key, muscle_label};
use crate::history::WorkoutRecord;
use crate::ids::derived_id;
use crate::pb::*;
use crate::plan::Planner;
use crate::progress::{compute_exercise_progress, compute_next_up_set, compute_workout_summary};
use crate::recovery::per_muscle_recovery;
use crate::rotation::rotation_check;
use crate::volume::{muscle_volume_7d, suggest_template};
use crate::workout::{
    active_proposed_sets, apply_answer_rung_to_active, get_workout_response_from_active,
    start_workout_response_from_active, workout_state_snapshot,
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

    /// A start: the template's exercises (a coupled one's from the library
    /// of now) and name, and each lift's decision, planned at the start's
    /// time in its budget — all recorded on the event.
    pub fn start_workout(
        &mut self,
        mut req: StartWorkoutRequest,
    ) -> Result<StartWorkoutResponse, CoreError> {
        if let Some(template) = self.account.template(&req.template_id) {
            let resolved = self.view().resolved(template);
            if req.exercises.is_empty() {
                req.exercises = resolved.exercises;
            }
            if req.name.is_empty() {
                req.name = resolved.name;
            }
        }
        let started_at = if req.started_at > 0 {
            req.started_at
        } else {
            self.now
        };
        req.decisions = Planner::new(self.account, started_at).workout(
            &exercises(&req.exercises),
            &[],
            req.budget_minutes,
        );
        let id = self.record(event::Kind::StartWorkout(req))?;
        Ok(start_workout_response_from_active(
            self.view().workout(&id)?,
            self.now,
        ))
    }

    pub fn end_workout(&mut self, req: EndWorkoutRequest) -> Result<EndWorkoutResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::EndWorkout(req))?;
        Ok(EndWorkoutResponse {
            workout: Some(self.view().workout(&id)?.workout.clone()),
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
        })
    }

    /// New lifts mid-workout (one already in it is not added again),
    /// planned now in the workout's budget around the lifts still in it,
    /// which keep their decisions.
    pub fn add_exercises(
        &mut self,
        mut req: AddExercisesRequest,
    ) -> Result<WorkoutPlanResponse, CoreError> {
        let id = req.workout_id.clone();
        let record = self.view().workout(&id)?;
        let planned: Vec<ExerciseDecision> = record
            .exercise_logs
            .iter()
            .filter_map(|log| log.decision.clone())
            .filter(|d| {
                record
                    .proposed_sets
                    .iter()
                    .any(|s| s.exercise == d.exercise && !s.cancelled)
            })
            .collect();
        let budget = planned.first().map(|d| d.budget_minutes).unwrap_or(0);
        let added: Vec<Exercise> = exercises(&req.exercises)
            .into_iter()
            .filter(|ex| planned.iter().all(|d| d.exercise != *ex as i32))
            .collect();
        req.decisions = Planner::new(self.account, self.now).workout(&added, &planned, budget);
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
    /// skipped and the rest still apply. New lifts are planned here, as
    /// `add_exercises` plans them.
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
            let _ = match payload {
                workout_mutation::Mutation::AddExercises(add) => {
                    self.add_exercises(add).map(|_| ())
                }
                other => self.mutate(other).map(|_| ()),
            };
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

    // ── Home, templates, overrides ──

    pub fn save_template(
        &mut self,
        mut req: SaveTemplateRequest,
    ) -> Result<SaveTemplateResponse, CoreError> {
        let given = req
            .template
            .as_ref()
            .map(|t| t.id.clone())
            .unwrap_or_default();
        if let (Some(existing), Some(saved)) = (self.account.template(&given), &mut req.template) {
            let shown = self.view().resolved(existing);
            if existing.coupled
                && !req.unlink
                && shown.name == saved.name
                && shown.exercises == saved.exercises
            {
                // Saving a coupled template as the library has it changes
                // nothing but, maybe, whether it is in rotation: that is
                // saved on the stored copy, so it stays coupled.
                if existing.in_rotation == saved.in_rotation {
                    return Ok(SaveTemplateResponse {
                        template: Some(shown),
                    });
                }
                saved.name = existing.name.clone();
                saved.exercises = existing.exercises.clone();
            } else {
                // Anything else is a real change to what the user sees, even
                // if it happens to match the copy stored when the template
                // was added.
                req.unlink = existing.coupled;
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

    pub fn set_override(
        &mut self,
        req: SetOverrideRequest,
    ) -> Result<SetOverrideResponse, CoreError> {
        let exercise = req.exercise();
        self.record(event::Kind::SetOverride(req))?;
        Ok(SetOverrideResponse {
            plan: Some(self.view().exercise_plan(exercise, 0)),
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
        let unit = crate::weight_units::unit_from_proto(req.unit);
        req.starting_weights = req
            .strength
            .map(|strength| exercise_weights(strength, unit))
            .unwrap_or_default();
        self.record(event::Kind::CompleteOnboarding(req))?;
        Ok(CompleteOnboardingResponse {
            home: Some(self.view().home(0)),
        })
    }

    pub fn add_library_templates(
        &mut self,
        mut req: AddLibraryTemplatesRequest,
    ) -> Result<AddLibraryTemplatesResponse, CoreError> {
        // An entry the user already has (following it, or their own made
        // from it) is not added again: no duplicates.
        req.library_ids
            .retain(|id| !self.account.has_library_entry(id));
        req.entries = self.library_entries(&req.library_ids)?;
        if !req.entries.is_empty() {
            self.record(event::Kind::AddLibraryTemplates(req))?;
        }
        Ok(AddLibraryTemplatesResponse {
            home: Some(self.view().home(0)),
        })
    }

    /// A ready-made plan as the main plan: its entries the user lacks are
    /// added, then one reorder puts the user's template for each entry
    /// first, in the plan's order, as the main plan, and every other
    /// template after it (the old main plan first) as a backup.
    pub fn apply_library_plan(
        &mut self,
        req: ApplyLibraryPlanRequest,
    ) -> Result<ApplyLibraryPlanResponse, CoreError> {
        let plan = crate::template_library::plans()
            .iter()
            .find(|p| p.id == req.plan_id)
            .ok_or_else(|| CoreError::NotFound(format!("unknown plan {:?}", req.plan_id)))?;
        let missing: Vec<String> = plan
            .library_ids
            .iter()
            .filter(|id| !self.account.has_library_entry(id))
            .cloned()
            .collect();
        if !missing.is_empty() {
            let entries = self.library_entries(&missing)?;
            self.record(event::Kind::AddLibraryTemplates(
                AddLibraryTemplatesRequest {
                    library_ids: missing,
                    entries,
                    in_rotation: false,
                },
            ))?;
        }
        let templates = &self.account.templates;
        let mut main: Vec<String> = Vec::with_capacity(plan.library_ids.len());
        for id in &plan.library_ids {
            // One already in the main plan before any other made from it.
            let from = |t: &&WorkoutTemplate| &t.library_id == id || &t.origin_library_id == id;
            let mine = templates
                .iter()
                .filter(from)
                .find(|t| t.in_rotation && !main.contains(&t.id))
                .or_else(|| {
                    templates
                        .iter()
                        .filter(from)
                        .find(|t| !main.contains(&t.id))
                })
                .ok_or_else(|| CoreError::NotFound(format!("no template for {id:?}")))?;
            main.push(mine.id.clone());
        }
        let rest = templates
            .iter()
            .filter(|t| t.in_rotation)
            .chain(templates.iter().filter(|t| !t.in_rotation))
            .filter(|t| !main.contains(&t.id))
            .map(|t| t.id.clone());
        let template_ids: Vec<String> = main.iter().cloned().chain(rest).collect();
        self.record(event::Kind::ReorderTemplates(ReorderTemplatesRequest {
            template_ids,
            rotation_count: Some(main.len() as i32),
        }))?;
        Ok(ApplyLibraryPlanResponse {
            home: Some(self.view().home(0)),
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

    /// A workout as the app shows it: visible sets, each lift's log.
    pub fn workout_response(&self, id: &str) -> Result<GetWorkoutResponse, CoreError> {
        let record = self.workout(id)?;
        let mut response = get_workout_response_from_active(record, self.now);
        response.rung_outcomes = self.rung_outcomes(record, &response.rung_question_set_id);
        // Cancelled rows mark a lift stopped early for the plan; the app
        // never shows them.
        response.proposed_sets.retain(|s| !s.cancelled);
        Ok(response)
    }

    /// What each range answer to the open rung question leads to: the
    /// answer applied to a copy of the workout, and the lift's next set
    /// read off it (a ramp set, or the working sets the ramp settles on).
    fn rung_outcomes(&self, record: &WorkoutRecord, set_id: &str) -> Vec<RungOutcome> {
        let Some(exercise) = record
            .proposed_sets
            .iter()
            .find(|s| s.id == set_id)
            .map(|s| s.exercise)
        else {
            return Vec::new();
        };
        [RepsLeft::ZeroToOne, RepsLeft::TwoToFour, RepsLeft::FivePlus]
            .into_iter()
            .filter_map(|reps_left| {
                let mut answered = record.clone();
                let req = AnswerRungRequest {
                    workout_id: record.workout.id.clone(),
                    proposed_set_id: set_id.to_string(),
                    reps_left: reps_left as i32,
                    jump_lb: 0.0,
                };
                apply_answer_rung_to_active(&mut answered, &req, self.account.unit(), self.now)
                    .ok()?;
                let done: std::collections::HashSet<&str> = answered
                    .completed_sets
                    .iter()
                    .map(|c| c.proposed_set_id.as_str())
                    .collect();
                let next = answered.proposed_sets.iter().find(|s| {
                    s.exercise == exercise
                        && !s.cancelled
                        && !s.warmup
                        && !done.contains(s.id.as_str())
                })?;
                Some(RungOutcome {
                    reps_left: reps_left as i32,
                    weight: next.target_weight,
                    settles: !next.calibration,
                })
            })
            .collect()
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
            exercises: self.with_estimated_max(compute_exercise_progress(&finished)),
        }
    }

    /// Each progress point gets the max the walk had after its session.
    fn with_estimated_max(&self, mut series: Vec<ExerciseProgress>) -> Vec<ExerciseProgress> {
        let planner = Planner::new(self.account, self.now);
        for progress in &mut series {
            let Ok(exercise) = Exercise::try_from(progress.exercise) else {
                continue;
            };
            let maxes: HashMap<String, f32> = planner.walk(exercise).points.into_iter().collect();
            for point in &mut progress.points {
                point.estimated_max = maxes.get(&point.workout_id).copied().unwrap_or(0.0);
            }
        }
        series
    }

    pub fn get_workout_heart_rate(
        &self,
        req: GetWorkoutHeartRateRequest,
    ) -> Result<GetWorkoutHeartRateResponse, CoreError> {
        let mut samples = self.workout(&req.workout_id)?.heart_rate.clone();
        samples.sort_by_key(|s| s.sampled_at);
        Ok(GetWorkoutHeartRateResponse { samples })
    }

    /// One lift's plan at now, on its own in `budget_minutes` (0 = the
    /// default).
    pub fn exercise_plan(&self, exercise: Exercise, budget_minutes: i32) -> ExercisePlan {
        let planner = Planner::new(self.account, self.now);
        let decision = planner
            .workout(&[exercise], &[], budget_minutes)
            .pop()
            .unwrap_or_default();
        planner.view(decision)
    }

    pub fn get_exercise_plan(
        &self,
        req: GetExercisePlanRequest,
    ) -> Result<GetExercisePlanResponse, CoreError> {
        Ok(GetExercisePlanResponse {
            plan: Some(self.exercise_plan(req.exercise(), req.budget_minutes)),
        })
    }

    /// `exercises` planned at now as one workout in `budget_minutes` (0 =
    /// the default): what starting a template of them would record.
    pub fn template_plan(&self, exercises: &[i32], budget_minutes: i32) -> TemplatePlan {
        self.plan_template(
            &Planner::new(self.account, self.now),
            exercises,
            budget_minutes,
        )
    }

    fn plan_template(
        &self,
        planner: &Planner,
        values: &[i32],
        budget_minutes: i32,
    ) -> TemplatePlan {
        let lifts = exercises(values);
        let decisions = planner.workout(&lifts, &[], budget_minutes);
        TemplatePlan {
            template_id: String::new(),
            estimated_seconds: decisions.iter().map(|d| d.estimated_seconds).sum(),
            max_seconds: planner.max_seconds(&lifts),
            plans: decisions.into_iter().map(|d| planner.view(d)).collect(),
        }
    }

    pub fn get_template_plan(
        &self,
        req: GetTemplatePlanRequest,
    ) -> Result<GetTemplatePlanResponse, CoreError> {
        Ok(GetTemplatePlanResponse {
            plan: Some(self.template_plan(&req.exercises, req.budget_minutes)),
        })
    }

    pub fn get_home(&self, req: GetHomeRequest) -> Result<GetHomeResponse, CoreError> {
        Ok(self.home(req.budget_minutes))
    }

    /// Everything the home screen needs, in one response, with every lift
    /// planned at now in `budget_minutes` (0 = the default).
    pub fn home(&self, budget_minutes: i32) -> GetHomeResponse {
        // Volume needs 7 days and recovery the latest session per muscle; a
        // fixed number of recent workouts keeps the work flat as history
        // grows.
        const RECENT: usize = 24;
        let mut recent: Vec<WorkoutRecord> = self.account.workouts.clone();
        recent.sort_by_key(|r| std::cmp::Reverse(r.workout.start_time));
        recent.truncate(RECENT);

        let budget = if budget_minutes > 0 {
            budget_minutes
        } else {
            crate::plan::DEFAULT_BUDGET_MINUTES
        };
        let planner = Planner::new(self.account, self.now);
        let plans = all_exercises()
            .into_iter()
            .filter_map(|exercise| planner.workout(&[exercise], &[], budget).pop())
            .map(|decision| planner.view(decision))
            .collect();
        let volume = muscle_volume_7d(&recent, self.now);
        let muscle_recovery = per_muscle_recovery(&recent, self.now);
        let recovery = muscle_recovery
            .iter()
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
        let suggestion = suggest_template(
            &templates,
            &volume,
            &muscle_recovery,
            self.now,
            &last_started,
        );
        // The library entries the user does not have, for the check's
        // additions.
        let addable: Vec<LibraryTemplate> = self
            .library
            .iter()
            .filter(|e| !self.account.has_library_entry(&e.id))
            .cloned()
            .collect();
        let template_plans = templates
            .iter()
            .map(|t| TemplatePlan {
                template_id: t.id.clone(),
                ..self.plan_template(&planner, &t.exercises, budget)
            })
            .collect();

        GetHomeResponse {
            onboarded: !templates.is_empty() || !self.account.workouts.is_empty(),
            plans,
            template_plans,
            budget_minutes: budget,
            active_workout_id: self.account.active_workout_id.clone(),
            volume,
            recovery,
            rotation_check: Some(rotation_check(&templates, &addable)),
            suggested_template_id: suggestion
                .as_ref()
                .map(|s| s.template_id.clone())
                .unwrap_or_default(),
            suggestion_reason: suggestion.map(|s| s.reason),
            templates,
        }
    }

    pub fn get_starting_weights(
        &self,
        req: GetStartingWeightsRequest,
    ) -> Result<GetStartingWeightsResponse, CoreError> {
        let unit = crate::weight_units::unit_from_proto(req.unit);
        let steps = (0..=100)
            .map(|step| StartingWeightsStep {
                weights: exercise_weights(step as f32 / 100.0, unit),
            })
            .collect();
        Ok(GetStartingWeightsResponse { steps })
    }

    pub fn list_template_library(&self) -> ListTemplateLibraryResponse {
        ListTemplateLibraryResponse {
            templates: self.library.to_vec(),
            // Only the plans whose every entry the library has.
            plans: crate::template_library::plans()
                .iter()
                .filter(|p| {
                    p.library_ids
                        .iter()
                        .all(|id| self.library.iter().any(|e| &e.id == id))
                })
                .cloned()
                .collect(),
        }
    }

    pub fn get_settings(&self) -> GetSettingsResponse {
        GetSettingsResponse {
            settings: self.account.settings.clone(),
        }
    }
}

/// The valid exercises of a list, in order, each once: a workout has a lift
/// at most once.
fn exercises(values: &[i32]) -> Vec<Exercise> {
    let mut out: Vec<Exercise> = Vec::new();
    for ex in values.iter().filter_map(|v| Exercise::try_from(*v).ok()) {
        if ex != Exercise::Unspecified && !out.contains(&ex) {
            out.push(ex);
        }
    }
    out
}

/// The main lifts' starting weights at `strength` on the setup slider.
fn exercise_weights(
    strength: f32,
    unit: crate::weight_units::AppWeightUnit,
) -> Vec<ExerciseWeight> {
    crate::onboarding::starting_weights_for_strength(strength, unit)
        .into_iter()
        .map(|(exercise, weight_lb)| ExerciseWeight {
            exercise: exercise as i32,
            weight_lb,
        })
        .collect()
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
            "SetOverride" => set_override,
            "CompleteOnboarding" => complete_onboarding,
            "AddLibraryTemplates" => add_library_templates,
            "ApplyLibraryPlan" => apply_library_plan,
            "CloneTemplate" => clone_template,
            "UpdateSetting" => update_setting,
            "ImportHistory" => import_history,
        }
        reads {
            "GetWorkout" => get_workout,
            "GetWorkoutHeartRate" => get_workout_heart_rate,
            "GetStartingWeights" => get_starting_weights,
            "GetHome" => get_home,
            "GetExercisePlan" => get_exercise_plan,
            "GetTemplatePlan" => get_template_plan,
        }
        plain {
            "GetActiveWorkout" => get_active_workout,
            "ListWorkoutSummaries" => list_workout_summaries,
            "GetExerciseProgress" => get_exercise_progress,
            "ListTemplateLibrary" => list_template_library,
            "GetSettings" => get_settings,
        }
    })
}
