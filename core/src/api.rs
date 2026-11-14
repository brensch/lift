//! The account's API: the app's RPCs, answered from an `Account`. A write
//! records an event (or a few) and answers from the account after it; a read
//! only looks. The phone calls these through [`call`] with the request's
//! proto bytes, so the app keeps its generated request and response types.

use std::collections::{BTreeSet, HashMap};

use prost::Message;

use crate::account::{follows, Account, CoreError};
use crate::events::*;
use crate::exercise_catalog::all_exercises;
use crate::history::{done_set_ids, WorkoutRecord};
use crate::ids::derived_id;
use crate::pb::*;
use crate::plan::Planner;
use crate::progress::{compute_exercise_progress, compute_workout_summary};
use crate::recovery::per_muscle_recovery;
use crate::rotation::rotation_check;
use crate::volume::{muscle_volume_7d, suggest_template};
use crate::workout::{
    apply_answer_rung_to_active, get_workout_response_from_active, rung_append_lifted,
    start_workout_response_from_active,
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

/// The longest motivational quote a workout keeps.
const MAX_MOTIVATION_CHARS: usize = 500;

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

    /// Record one fact: applied to the account and kept, or (on an error)
    /// neither. Returns the event's id. It has no place in the account's
    /// history until the server gives it one. One that would not read back
    /// once stored (a NaN or infinite number in it) is refused.
    fn record(&mut self, fact: Fact) -> Result<String, CoreError> {
        let id = match self.events.len() {
            0 => self.event_id.clone(),
            n => derived_id(&self.event_id, n),
        };
        let event = Event {
            seq: 0,
            id: id.clone(),
            at: self.now,
            fact,
        };
        if !event.reads_back() {
            return Err(CoreError::InvalidArgument(
                "A number in it can't be stored".into(),
            ));
        }
        self.account.apply(&event)?;
        self.events.push(event);
        Ok(id)
    }

    fn mutate(&mut self, mutation: workout_mutation::Mutation) -> Result<String, CoreError> {
        let mut fact = workout_fact(mutation, self.now);
        self.check(&fact)?;
        if let Fact::WorkoutEnded(ended) = &mut fact {
            if let Some(record) = self.account.workout(&ended.workout_id) {
                ended.ended_at = trimmed_end(record, ended.ended_at);
            }
        }
        self.record(fact)
    }

    /// Refuse a change to a workout the fold would take but that must not
    /// be written: a done set with negative reps or a negative or
    /// non-finite weight, or the undo of a rung whose append was lifted
    /// (done again, it would append twice). Stored facts fold as they
    /// always have.
    fn check(&self, fact: &Fact) -> Result<(), CoreError> {
        match fact {
            Fact::SetCompleted(r) if r.actual_reps < 0 => {
                Err(CoreError::InvalidArgument("Reps must be at least 0".into()))
            }
            Fact::SetCompleted(r) if !(r.actual_weight.is_finite() && r.actual_weight >= 0.0) => {
                Err(CoreError::InvalidArgument("Weight out of range".into()))
            }
            Fact::SetUndone(r)
                if self
                    .account
                    .workout(&r.workout_id)
                    .is_some_and(|w| rung_append_lifted(w, &r.completed_set_id)) =>
            {
                Err(CoreError::FailedPrecondition(
                    "Undo the sets this rung added first".into(),
                ))
            }
            _ => Ok(()),
        }
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
        check_decisions(&req.decisions)?;
        if req.name.is_empty() {
            req.name = "Workout".to_string();
        }
        let id = self.record(Fact::WorkoutStarted(WorkoutStarted {
            name: req.name,
            unit: self.account.unit().to_proto(),
            started_at,
            template_id: req.template_id,
            exercises: req.exercises,
            budget_minutes: req.budget_minutes,
            decisions: req.decisions,
            motivation: req.motivation.chars().take(MAX_MOTIVATION_CHARS).collect(),
        }))?;
        Ok(start_workout_response_from_active(
            self.view().workout(&id)?,
            self.now,
        ))
    }

    /// Throw a workout away: it is gone from the account.
    pub fn discard_workout(
        &mut self,
        req: DiscardWorkoutRequest,
    ) -> Result<DiscardWorkoutResponse, CoreError> {
        self.record(Fact::WorkoutDiscarded(WorkoutDiscarded {
            workout_id: req.workout_id,
        }))?;
        Ok(DiscardWorkoutResponse {})
    }

    pub fn end_workout(&mut self, req: EndWorkoutRequest) -> Result<EndWorkoutResponse, CoreError> {
        let id = req.workout_id.clone();
        self.mutate(workout_mutation::Mutation::EndWorkout(req))?;
        let view = self.view();
        let record = view.workout(&id)?;
        Ok(EndWorkoutResponse {
            workout: Some(record.workout.clone()),
            template_offer: view.template_offer(record),
        })
    }

    /// New lifts mid-workout (one already in it is not added again),
    /// planned now in the workout's budget around the lifts still in it,
    /// which keep their decisions.
    fn add_exercises(&mut self, mut req: AddExercisesRequest) -> Result<String, CoreError> {
        let record = self.view().workout(&req.workout_id)?;
        // Each lift still in it once, by its latest decision: one removed
        // and added again has an older log too.
        let planned: Vec<ExerciseDecision> = record
            .exercise_logs
            .iter()
            .filter_map(|log| log.decision.as_ref())
            .filter(|d| {
                record
                    .decision(d.exercise)
                    .is_some_and(|latest| std::ptr::eq(latest, *d))
            })
            .filter(|d| {
                record
                    .proposed_sets
                    .iter()
                    .any(|s| s.exercise == d.exercise && !s.cancelled)
            })
            .cloned()
            .collect();
        let budget = planned.first().map(|d| d.budget_minutes).unwrap_or(0);
        let added: Vec<Exercise> = exercises(&req.exercises)
            .into_iter()
            .filter(|ex| planned.iter().all(|d| d.exercise != *ex as i32))
            .collect();
        req.decisions = Planner::new(self.account, self.now).workout(&added, &planned, budget);
        check_decisions(&req.decisions)?;
        self.record(Fact::ExercisesAdded(ExercisesAdded {
            workout_id: req.workout_id,
            exercises: req.exercises,
            decisions: req.decisions,
        }))
    }

    /// Several changes in one go. One that can't apply — a set already
    /// gone, a workout already over — is skipped and the rest still apply.
    /// One the core refuses (`check`: a done set out of range, the undo of
    /// a rung whose append was lifted) ends the call with an error, so the
    /// app can say why; any before it are already recorded on the `Call`,
    /// and the store goes back to its file, so on the phone nothing of the
    /// call is kept. New lifts are planned here (`add_exercises`).
    pub fn append_workout_mutations(
        &mut self,
        req: AppendWorkoutMutationsRequest,
    ) -> Result<AppendWorkoutMutationsResponse, CoreError> {
        let mut workout_id = None;
        for mutation in req.mutations {
            // An empty one (or a kind this build doesn't know) is skipped
            // like any other that can't apply.
            let Some(payload) = mutation.mutation else {
                continue;
            };
            match payload {
                workout_mutation::Mutation::AddExercises(add) => {
                    workout_id.get_or_insert_with(|| add.workout_id.clone());
                    let _ = self.add_exercises(add);
                }
                other => {
                    let fact = workout_fact(other, self.now);
                    workout_id
                        .get_or_insert_with(|| fact.workout_id().unwrap_or_default().to_string());
                    self.check(&fact)?;
                    let _ = self.record(fact);
                }
            }
        }
        Ok(AppendWorkoutMutationsResponse {
            workout_state: match workout_id {
                Some(id) => self.view().workout_response(&id).ok(),
                None => None,
            },
        })
    }

    /// A finished workout's heart rate, whole, as one event. Not an RPC: the
    /// phone gathers readings while the workout runs and records them once
    /// it has ended (`app/native`'s store).
    /// Readings outside the workout (before its start, after its end) are
    /// left out.
    pub fn record_heart_rate(
        &mut self,
        workout_id: &str,
        samples: &[WorkoutHeartRatePoint],
    ) -> Result<(), CoreError> {
        let record = self
            .account
            .workout(workout_id)
            .ok_or_else(|| CoreError::NotFound("Workout not found".into()))?;
        let within: Vec<WorkoutHeartRatePoint> = samples
            .iter()
            .filter(|s| within_workout(&record.workout, s.sampled_at))
            .cloned()
            .collect();
        self.record(Fact::HeartRateRecorded(HeartRateRecorded::new(
            workout_id, &within,
        )))?;
        Ok(())
    }

    /// Move a finished workout's end earlier (a correction: a workout left
    /// running after its last set). Not an RPC.
    pub fn move_workout_end(&mut self, workout_id: &str, ended_at: i64) -> Result<(), CoreError> {
        self.record(Fact::WorkoutEndMoved(WorkoutEndMoved {
            workout_id: workout_id.to_string(),
            ended_at,
        }))?;
        Ok(())
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
        let template = req
            .template
            .ok_or_else(|| CoreError::InvalidArgument("template is required".into()))?;
        let event_id = self.record(Fact::TemplateSaved(TemplateSaved {
            template,
            unlink: req.unlink,
        }))?;
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

    pub fn delete_template(
        &mut self,
        req: DeleteTemplateRequest,
    ) -> Result<DeleteTemplateResponse, CoreError> {
        self.record(Fact::TemplateDeleted(TemplateDeleted {
            template_id: req.template_id,
        }))?;
        Ok(DeleteTemplateResponse {})
    }

    pub fn reorder_templates(
        &mut self,
        req: ReorderTemplatesRequest,
    ) -> Result<ReorderTemplatesResponse, CoreError> {
        self.record(Fact::TemplatesReordered(TemplatesReordered {
            template_ids: req.template_ids,
            rotation_count: req.rotation_count,
        }))?;
        Ok(ReorderTemplatesResponse {})
    }

    pub fn set_override(
        &mut self,
        req: SetOverrideRequest,
    ) -> Result<SetOverrideResponse, CoreError> {
        let exercise = req.exercise();
        self.record(Fact::OverrideSet(OverrideSet {
            exercise: req.exercise,
            weight: req.weight,
            reps: req.reps,
            sets: req.sets,
        }))?;
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
        self.record(Fact::Onboarded(Onboarded {
            unit: req.unit,
            library_entries: req.library_entries,
            strength: req.strength,
            starting_weights: req.starting_weights,
        }))?;
        Ok(CompleteOnboardingResponse {})
    }

    pub fn add_library_templates(
        &mut self,
        mut req: AddLibraryTemplatesRequest,
    ) -> Result<AddLibraryTemplatesResponse, CoreError> {
        // An entry the user already has (following it, or their own made
        // from it) is not added again: no duplicates.
        req.library_ids
            .retain(|id| !self.account.has_library_entry(id));
        let entries = self.library_entries(&req.library_ids)?;
        if !entries.is_empty() {
            self.record(Fact::LibraryTemplatesAdded(LibraryTemplatesAdded {
                entries,
                in_rotation: req.in_rotation,
            }))?;
        }
        Ok(AddLibraryTemplatesResponse {})
    }

    /// A ready-made plan as the rotation: its entries the user lacks are
    /// added, then one reorder puts the user's template for each entry
    /// first, in the plan's order, as the rotation, and every other
    /// template after it (the old rotation first) as a reserve.
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
            self.record(Fact::LibraryTemplatesAdded(LibraryTemplatesAdded {
                entries,
                in_rotation: false,
            }))?;
        }
        let templates = &self.account.templates;
        let mut rotation: Vec<String> = Vec::with_capacity(plan.library_ids.len());
        for id in &plan.library_ids {
            // One already in the rotation before any other made from it.
            let from = |t: &&WorkoutTemplate| follows(t, id);
            let mine = templates
                .iter()
                .filter(from)
                .find(|t| t.in_rotation && !rotation.contains(&t.id))
                .or_else(|| {
                    templates
                        .iter()
                        .filter(from)
                        .find(|t| !rotation.contains(&t.id))
                })
                .ok_or_else(|| CoreError::NotFound(format!("no template for {id:?}")))?;
            rotation.push(mine.id.clone());
        }
        let rest = templates
            .iter()
            .filter(|t| t.in_rotation)
            .chain(templates.iter().filter(|t| !t.in_rotation))
            .filter(|t| !rotation.contains(&t.id))
            .map(|t| t.id.clone());
        let template_ids: Vec<String> = rotation.iter().cloned().chain(rest).collect();
        self.record(Fact::TemplatesReordered(TemplatesReordered {
            template_ids,
            rotation_count: Some(rotation.len() as i32),
        }))?;
        Ok(ApplyLibraryPlanResponse {})
    }

    /// Bring in history from elsewhere as it was (an account moving here).
    pub fn import_history(
        &mut self,
        req: ImportHistory,
    ) -> Result<ImportHistoryResponse, CoreError> {
        self.record(Fact::HistoryImported(HistoryImported {
            workouts: req.workouts,
            starting_weights: req.starting_weights,
        }))?;
        Ok(ImportHistoryResponse {})
    }

    // ── Settings ──

    pub fn update_setting(
        &mut self,
        req: UpdateSettingRequest,
    ) -> Result<UpdateSettingResponse, CoreError> {
        let setting = req
            .setting
            .ok_or_else(|| CoreError::InvalidArgument("setting is required".into()))?;
        self.record(Fact::SettingUpdated(SettingUpdated { setting }))?;
        Ok(UpdateSettingResponse {})
    }
}

/// The longest a workout runs on after its last set: that set's rest, or
/// this, whichever is shorter. Time after it is not training.
pub const END_AFTER_LAST_SET_SECONDS: i64 = 5 * 60;

/// When a workout ends: when asked (`requested`), but no later than its last
/// set's end plus that set's rest (`END_AFTER_LAST_SET_SECONDS` at most), so
/// a workout left running after it finished stops where the training did.
/// One with no set done ends when asked. The start always counts.
pub fn trimmed_end(record: &WorkoutRecord, requested: i64) -> i64 {
    let Some(last) = record.completed_sets.iter().max_by_key(|c| c.ended_at) else {
        return requested;
    };
    let rest = (last.rest_until - last.ended_at).clamp(0, END_AFTER_LAST_SET_SECONDS);
    requested.min(last.ended_at + rest).max(last.ended_at)
}

/// Whether a heart-rate reading (unix ms) falls within the workout: from its
/// start to its end, or on while it runs.
fn within_workout(workout: &Workout, sampled_at_ms: i64) -> bool {
    sampled_at_ms >= workout.start_time * 1000
        && (workout.end_time == 0 || sampled_at_ms <= workout.end_time * 1000)
}

/// A change to a workout as the fact it records, its times decided: a time
/// of 0 is `now`. New lifts are planned by the caller first.
fn workout_fact(mutation: workout_mutation::Mutation, now: i64) -> Fact {
    use workout_mutation::Mutation as M;
    let or_now = |at: i64| if at > 0 { at } else { now };
    match mutation {
        M::StartSet(r) => Fact::SetStarted(SetStarted {
            workout_id: r.workout_id,
            proposed_set_id: r.proposed_set_id,
            started_at: or_now(r.started_at),
        }),
        M::CompleteSet(r) => Fact::SetCompleted(SetCompleted {
            workout_id: r.workout_id,
            proposed_set_id: r.proposed_set_id,
            actual_reps: r.actual_reps,
            actual_weight: r.actual_weight,
            completed_at: or_now(r.completed_at),
        }),
        M::EditCompletedSet(r) => Fact::SetEdited(SetEdited {
            workout_id: r.workout_id,
            completed_set_id: r.completed_set_id,
            actual_reps: r.actual_reps,
            actual_weight: r.actual_weight,
        }),
        M::DeleteCompletedSet(r) => Fact::SetUndone(SetUndone {
            workout_id: r.workout_id,
            completed_set_id: r.completed_set_id,
        }),
        M::AnswerRung(r) => Fact::RungAnswered(RungAnswered {
            workout_id: r.workout_id,
            proposed_set_id: r.proposed_set_id,
            reps_left: r.reps_left,
            jump_lb: r.jump_lb,
        }),
        M::SkipWarmups(r) => Fact::WarmupsSkipped(WarmupsSkipped {
            workout_id: r.workout_id,
            exercise: r.exercise,
            proposed_set_id: r.proposed_set_id,
        }),
        M::AddExercises(r) => Fact::ExercisesAdded(ExercisesAdded {
            workout_id: r.workout_id,
            exercises: r.exercises,
            decisions: r.decisions,
        }),
        M::AdjustExerciseWeight(r) => Fact::ExerciseAdjusted(ExerciseAdjusted {
            workout_id: r.workout_id,
            exercise: r.exercise,
            working_weight: r.working_weight,
            target_reps: r.target_reps,
            sets: r.sets,
        }),
        M::RemoveExercise(r) => Fact::ExerciseRemoved(ExerciseRemoved {
            workout_id: r.workout_id,
            exercise: r.exercise,
        }),
        M::ReorderExercises(r) => Fact::ExercisesReordered(ExercisesReordered {
            workout_id: r.workout_id,
            exercises: r.exercises,
        }),
        M::SetSession(r) => Fact::SessionSet(SessionSet {
            workout_id: r.workout_id,
            session_id: r.session_id,
        }),
        M::EndWorkout(r) => Fact::WorkoutEnded(WorkoutEnded {
            workout_id: r.workout_id,
            ended_at: or_now(r.ended_at),
        }),
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

    /// "Save these lifts as a template?" for a workout: the lifts with a
    /// done working set, in workout order, unless they are the ones of the
    /// template it started from. None when nothing was done, or the
    /// template it started from is gone.
    fn template_offer(&self, record: &WorkoutRecord) -> Option<TemplateOffer> {
        let mut exercises: Vec<i32> = Vec::new();
        for set in &record.proposed_sets {
            let done = record
                .completed_sets
                .iter()
                .any(|c| c.proposed_set_id == set.id);
            if done && !set.warmup && !set.cancelled && !exercises.contains(&set.exercise) {
                exercises.push(set.exercise);
            }
        }
        if exercises.is_empty() {
            return None;
        }
        let template_id = &record.workout.template_id;
        if template_id.is_empty() {
            return Some(TemplateOffer {
                exercises,
                ..Default::default()
            });
        }
        let template = self.resolved(self.account.template(template_id)?);
        let planned: BTreeSet<i32> = template.exercises.iter().copied().collect();
        let same =
            planned.len() == exercises.len() && exercises.iter().all(|e| planned.contains(e));
        (!same).then_some(TemplateOffer {
            template_id: template.id,
            template_name: template.name,
            exercises,
        })
    }

    fn workout(&self, id: &str) -> Result<&'a WorkoutRecord, CoreError> {
        self.account
            .workout(id)
            .ok_or_else(|| CoreError::NotFound("Workout not found".into()))
    }

    /// A workout as the app shows it: visible sets, each lift's log and,
    /// once it is finished, the estimated max after it.
    pub fn workout_response(&self, id: &str) -> Result<GetWorkoutResponse, CoreError> {
        let record = self.workout(id)?;
        let mut response = get_workout_response_from_active(record, self.now);
        response.rung_outcomes = self.rung_outcomes(record, &response.rung_question_set_id);
        // Cancelled rows mark a lift stopped early for the plan; the app
        // never shows them.
        response.proposed_sets.retain(|s| !s.cancelled);
        // A lift's max moves only once its workout is finished.
        if let Some(summary) = response
            .summary
            .as_mut()
            .filter(|_| record.workout.end_time > 0)
        {
            let planner = Planner::new(self.account, self.now);
            for lift in &mut summary.exercises {
                let Ok(exercise) = Exercise::try_from(lift.exercise) else {
                    continue;
                };
                lift.estimated_max_after = planner
                    .walk(exercise)
                    .points
                    .into_iter()
                    .find(|(workout_id, _)| *workout_id == record.workout.id)
                    .map_or(0.0, |(_, max)| max);
            }
        }
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
                let mut answered = record.without_heart_rate();
                let req = RungAnswered {
                    workout_id: record.workout.id.clone(),
                    proposed_set_id: set_id.to_string(),
                    reps_left: reps_left as i32,
                    jump_lb: 0.0,
                };
                apply_answer_rung_to_active(&mut answered, &req, record.unit, self.now);
                let done = done_set_ids(&answered.completed_sets);
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

    pub fn get_workout(&self, req: GetWorkoutRequest) -> Result<GetWorkoutResponse, CoreError> {
        self.workout_response(&req.workout_id)
    }

    /// The workout as an adjust would leave it, without making it: nothing
    /// is recorded. For the edit sheet to show what its numbers lead to
    /// (the warmups a working weight gives) before Save.
    pub fn preview_adjust_exercise(
        &self,
        req: AdjustExerciseWeightRequest,
    ) -> Result<GetWorkoutResponse, CoreError> {
        let mut record = self.workout(&req.workout_id)?.without_heart_rate();
        let unit = record.unit;
        crate::workout::apply_adjust_exercise_weight(
            &mut record,
            &ExerciseAdjusted {
                workout_id: req.workout_id,
                exercise: req.exercise,
                working_weight: req.working_weight,
                target_reps: req.target_reps,
                sets: req.sets,
            },
            unit,
            &mut crate::ids::Ids::new("preview"),
            self.now,
        )
        .map_err(CoreError::from)?;
        let mut response = get_workout_response_from_active(&record, self.now);
        response.proposed_sets.retain(|s| !s.cancelled);
        Ok(response)
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
        let volume = muscle_volume_7d(&self.account.workouts, self.now);
        let muscle_recovery = per_muscle_recovery(&self.account.workouts);
        let recovery = muscle_recovery
            .iter()
            .map(|entry| MuscleRecoveryStatus {
                muscle: entry.muscle as i32,
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
            addable_library_ids: addable.iter().map(|e| e.id.clone()).collect(),
            current_plan_id: current_plan(&templates)
                .map(|p| p.id.clone())
                .unwrap_or_default(),
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

/// The ready-made plan the rotation already is: the same workouts, each
/// following or made from one of the plan's entries. The order is not
/// compared (the suggestion does not go through the rotation in order).
fn current_plan(templates: &[WorkoutTemplate]) -> Option<&'static LibraryPlan> {
    let rotation: Vec<&WorkoutTemplate> = templates.iter().filter(|t| t.in_rotation).collect();
    crate::template_library::plans().iter().find(|plan| {
        let mut left: Vec<&String> = plan.library_ids.iter().collect();
        rotation.len() == left.len()
            && rotation.iter().all(|t| {
                let at = |id: &str| left.iter().position(|l| l.as_str() == id);
                match at(&t.library_id).or_else(|| at(&t.origin_library_id)) {
                    Some(i) => {
                        left.remove(i);
                        true
                    }
                    None => false,
                }
            })
    })
}

/// A plan nothing in the app arrives at (a weight past what any history or
/// override leads to, more sets than an override may ask) is refused rather
/// than recorded: every device and partner folds what is recorded.
fn check_decisions(decisions: &[ExerciseDecision]) -> Result<(), CoreError> {
    for d in decisions {
        if !(0.0..=10_000.0).contains(&d.weight) || !(1..=20).contains(&d.sets) {
            return Err(CoreError::InvalidArgument(
                "The plan is out of range".to_string(),
            ));
        }
    }
    Ok(())
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
            "DiscardWorkout" => discard_workout,
            "AppendWorkoutMutations" => append_workout_mutations,
            "SaveTemplate" => save_template,
            "DeleteTemplate" => delete_template,
            "ReorderTemplates" => reorder_templates,
            "SetOverride" => set_override,
            "CompleteOnboarding" => complete_onboarding,
            "AddLibraryTemplates" => add_library_templates,
            "ApplyLibraryPlan" => apply_library_plan,
            "UpdateSetting" => update_setting,
            "ImportHistory" => import_history,
        }
        reads {
            "GetWorkout" => get_workout,
            "PreviewAdjustExercise" => preview_adjust_exercise,
            "GetWorkoutHeartRate" => get_workout_heart_rate,
            "GetStartingWeights" => get_starting_weights,
            "GetHome" => get_home,
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
