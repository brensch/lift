//! The account's API: the app's RPCs, answered from an `Account`. A write
//! records an event (or a few) and answers from the account after it; a read
//! only looks. The phone calls these through [`call`] with the request's
//! proto bytes, so the app keeps its generated request and response types.
//!
//! The program is the account's every training rule
//! (`crate::program`). The template editor, the rotation and onboarding
//! edit it: each is one `ProgramSet`, the whole document with the change
//! made. An assistant sets it whole (`set_program`).

use std::collections::{BTreeSet, HashMap};

use prost::Message;

use crate::account::{Account, CoreError, ProgramVersion};
use crate::events::*;
use crate::history::{done_set_ids, WorkoutRecord};
use crate::ids::derived_id;
use crate::pb::*;
use crate::plan::Planner;
use crate::program::{self, Problem, Program, ProgramRef, WorkoutDef, GUIDE};
use crate::progress::{compute_exercise_progress, compute_workout_summary};
use crate::recovery::per_muscle_recovery;
use crate::rotation::rotation_check;
use crate::volume::{muscle_volume, suggest_template};
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
}

/// The longest motivational quote a workout keeps.
const MAX_MOTIVATION_CHARS: usize = 500;
/// The longest note a program is set with.
const MAX_NOTE_CHARS: usize = 300;

/// Who set a program from the app.
pub const AUTHOR_APP: &str = "app";

impl<'a> Call<'a> {
    pub fn view(&self) -> View<'_> {
        View::new(self.account, self.now)
    }

    pub fn new(account: &'a mut Account, now: i64, event_id: impl Into<String>) -> Self {
        Self {
            account,
            now,
            event_id: event_id.into(),
            events: Vec::new(),
        }
    }

    /// The id the next event this call records takes.
    fn next_event_id(&self) -> String {
        match self.events.len() {
            0 => self.event_id.clone(),
            n => derived_id(&self.event_id, n),
        }
    }

    /// Record one fact: applied to the account and kept, or (on an error)
    /// neither. Returns the event's id. It has no place in the account's
    /// history until the server gives it one. One that would not read back
    /// once stored (a NaN or infinite number in it) is refused.
    fn record(&mut self, fact: Fact) -> Result<String, CoreError> {
        let id = self.next_event_id();
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

    /// A start: the template's exercises and name, and each lift's
    /// decision, planned by the program at the start's time in its budget —
    /// all recorded on the event, with the program's id.
    pub fn start_workout(
        &mut self,
        mut req: StartWorkoutRequest,
    ) -> Result<StartWorkoutResponse, CoreError> {
        if let Some(template) = self.account.program.workout(&req.template_id) {
            if req.exercises.is_empty() {
                req.exercises = template.exercises.clone();
            }
            if req.name.is_empty() {
                req.name = template.name.clone();
            }
        }
        let started_at = if req.started_at > 0 {
            req.started_at
        } else {
            self.now
        };
        let exercises = known_exercises(&self.account.program, &req.exercises);
        let decisions =
            Planner::new(self.account, started_at).workout(&exercises, &[], req.budget_minutes);
        check_decisions(&decisions)?;
        if req.name.is_empty() {
            req.name = "Workout".to_string();
        }
        let rules = Some(Box::new(self.account.program.rules_for(&exercises)));
        let id = self.record(Fact::WorkoutStarted(WorkoutStarted {
            name: req.name,
            unit: self.account.unit().to_proto(),
            started_at,
            template_id: req.template_id,
            exercises,
            budget_minutes: req.budget_minutes,
            decisions,
            motivation: req.motivation.chars().take(MAX_MOTIVATION_CHARS).collect(),
            program_id: self.account.program_id().to_string(),
            rules,
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
    fn add_exercises(&mut self, req: AddExercisesRequest) -> Result<String, CoreError> {
        let record = self.view().workout(&req.workout_id)?;
        // Each lift still in it once, by its latest decision: one removed
        // and added again has an older log too.
        let planned: Vec<ExerciseDecision> = record
            .exercise_logs
            .iter()
            .filter_map(|log| log.decision.as_ref())
            .filter(|d| {
                record
                    .decision(&d.exercise)
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
        let added: Vec<String> = known_exercises(&self.account.program, &req.exercises)
            .into_iter()
            .filter(|ex| planned.iter().all(|d| &d.exercise != ex))
            .collect();
        if added.is_empty() {
            return Err(CoreError::FailedPrecondition(
                "Every lift is in the workout already".into(),
            ));
        }
        let decisions = Planner::new(self.account, self.now).workout(&added, &planned, budget);
        check_decisions(&decisions)?;
        self.record(Fact::ExercisesAdded(ExercisesAdded {
            workout_id: req.workout_id,
            definitions: self.account.program.definitions(&added),
            exercises: added,
            decisions,
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

    // ── The program ──

    /// Record `program` as the account's, by `author`, when it checks out:
    /// no errors in it, and every exercise the account has used still in
    /// it. Returns the problems either way; nothing is recorded with an
    /// error among them.
    pub fn record_program(
        &mut self,
        program: Program,
        author: &str,
        note: &str,
    ) -> Result<Vec<Problem>, CoreError> {
        let mut problems = program::check(&program);
        problems.extend(program::validate_for_account(
            &program,
            &self.account.exercises_used(),
        ));
        if problems.iter().any(|p| p.error) {
            return Ok(problems);
        }
        self.record(Fact::ProgramSet(ProgramSet {
            program: ProgramRef::new(program),
            author: author.to_string(),
            note: note.chars().take(MAX_NOTE_CHARS).collect(),
        }))?;
        Ok(problems)
    }

    /// One edit to the program's workouts, recorded: refused, recording
    /// nothing, when it would leave the program with an error.
    fn edit(&mut self, edit: WorkoutsEdit) -> Result<(), CoreError> {
        self.record(Fact::ProgramEdited(ProgramEdited { edit }))?;
        Ok(())
    }

    pub fn set_program(&mut self, req: SetProgramRequest) -> Result<SetProgramResponse, CoreError> {
        let (program, mut problems) = program::validate(&req.program_json);
        let author = if req.author.is_empty() {
            AUTHOR_APP
        } else {
            req.author.as_str()
        };
        if let Some(program) = program.filter(|_| !problems.iter().any(|p| p.error)) {
            problems = self.record_program(program, author, &req.note)?;
        }
        let set = !problems.iter().any(|p| p.error);
        Ok(SetProgramResponse {
            problems: problems.iter().map(problem_proto).collect(),
            summary: set.then(|| self.view().program_summary()),
        })
    }

    /// Back to the built-in rules, the workouts kept — and any exercise of
    /// the program's own they or the history name, so nothing is lost.
    pub fn reset_program(
        &mut self,
        _req: ResetProgramRequest,
    ) -> Result<ResetProgramResponse, CoreError> {
        let current = self.account.program.clone();
        let mut program = Program::builtin().with_workouts(current.workouts.clone());
        let mut keep: BTreeSet<String> = self.account.exercises_used();
        keep.extend(current.workouts.iter().flat_map(|w| w.exercises.clone()));
        let fallback_class = program.classes.keys().next().cloned().unwrap_or_default();
        for key in keep {
            if program.knows(&key) {
                continue;
            }
            if let Some(def) = current.exercise(&key) {
                let mut def = def.clone();
                def.progression = None;
                if !program.classes.contains_key(&def.class) {
                    def.class = fallback_class.clone();
                }
                program.exercises.push(def);
            }
        }
        let problems = self.record_program(program, AUTHOR_APP, "")?;
        if let Some(p) = problems.into_iter().find(|p| p.error) {
            return Err(CoreError::FailedPrecondition(problem_text(&p)));
        }
        Ok(ResetProgramResponse {
            summary: Some(self.view().program_summary()),
        })
    }

    // ── Templates: the program's workouts ──

    /// Make (empty id) or change one of the program's workouts. Its
    /// exercises are the ones the program knows, each once.
    pub fn save_template(
        &mut self,
        req: SaveTemplateRequest,
    ) -> Result<SaveTemplateResponse, CoreError> {
        let template = req
            .template
            .ok_or_else(|| CoreError::InvalidArgument("template is required".into()))?;
        if template.name.trim().is_empty() {
            return Err(CoreError::InvalidArgument("A template needs a name".into()));
        }
        let exercises = known_exercises(&self.account.program, &template.exercises);
        if exercises.is_empty() {
            return Err(CoreError::InvalidArgument(
                "A template needs at least one exercise".into(),
            ));
        }
        let existing = self.account.program.workout(&template.id);
        let workout = WorkoutDef {
            id: if template.id.is_empty() {
                derived_id(&self.next_event_id(), 0)
            } else {
                template.id.clone()
            },
            name: template.name.trim().to_string(),
            exercises,
            rotation: template.in_rotation,
            notes: template.notes.clone(),
            from_library: existing.map(|w| w.from_library.clone()).unwrap_or_default(),
        };
        let id = workout.id.clone();
        if existing != Some(&workout) {
            self.edit(WorkoutsEdit::Save { workout })?;
        }
        Ok(SaveTemplateResponse {
            template: self.account.program.workout(&id).map(template_of),
        })
    }

    pub fn delete_template(
        &mut self,
        req: DeleteTemplateRequest,
    ) -> Result<DeleteTemplateResponse, CoreError> {
        if self.account.program.workout(&req.template_id).is_some() {
            self.edit(WorkoutsEdit::Delete {
                workout_id: req.template_id,
            })?;
        }
        Ok(DeleteTemplateResponse {})
    }

    /// The workouts in this order (any not named keep theirs, after); with
    /// `rotation_count`, the first that many are the rotation, the rest
    /// reserves.
    pub fn reorder_templates(
        &mut self,
        req: ReorderTemplatesRequest,
    ) -> Result<ReorderTemplatesResponse, CoreError> {
        if req.rotation_count.is_some_and(|n| n < 0) {
            return Err(CoreError::InvalidArgument(
                "rotation_count is negative".into(),
            ));
        }
        self.edit(WorkoutsEdit::Reorder {
            workout_ids: req.template_ids,
            rotation_count: req.rotation_count,
        })?;
        Ok(ReorderTemplatesResponse {})
    }

    pub fn set_override(
        &mut self,
        req: SetOverrideRequest,
    ) -> Result<SetOverrideResponse, CoreError> {
        let exercise = req.exercise.clone();
        self.record(Fact::OverrideSet(OverrideSet {
            exercise: req.exercise,
            weight: req.weight,
            reps: req.reps,
            sets: req.sets,
        }))?;
        Ok(SetOverrideResponse {
            plan: Some(self.view().exercise_plan(&exercise, 0)),
        })
    }

    /// Sign-up: the unit and the starting weights `strength` picks, then —
    /// the first time, while the program has no workouts — the library
    /// entries chosen (the defaults when none are) as the rotation.
    pub fn complete_onboarding(
        &mut self,
        req: CompleteOnboardingRequest,
    ) -> Result<CompleteOnboardingResponse, CoreError> {
        let first = self.account.program.workouts.is_empty();
        let entries: Vec<LibraryTemplate> = if req.library_ids.is_empty() {
            crate::template_library::library()
                .iter()
                .filter(|e| e.is_default)
                .cloned()
                .collect()
        } else {
            library_entries(&req.library_ids)?
        };
        let unit = crate::weight_units::unit_from_proto(req.unit);
        let starting_weights = match (first, req.strength) {
            (true, Some(strength)) => exercise_weights(&self.account.program, strength, unit),
            _ => Vec::new(),
        };
        self.record(Fact::Onboarded(Onboarded {
            unit: req.unit,
            strength: req.strength,
            starting_weights,
        }))?;
        if first && !entries.is_empty() {
            let event_id = self.next_event_id();
            let workouts = entries
                .iter()
                .enumerate()
                .map(|(n, entry)| library_copy(entry, true, &event_id, n))
                .collect();
            self.edit(WorkoutsEdit::Add { workouts })?;
        }
        Ok(CompleteOnboardingResponse {})
    }

    /// Copy library entries into the program's workouts, skipping any the
    /// user already has (a workout copied from it).
    pub fn add_library_templates(
        &mut self,
        req: AddLibraryTemplatesRequest,
    ) -> Result<AddLibraryTemplatesResponse, CoreError> {
        let wanted: Vec<String> = req
            .library_ids
            .into_iter()
            .filter(|id| !has_library_entry(&self.account.program, id))
            .collect();
        let entries = library_entries(&wanted)?;
        if !entries.is_empty() {
            let event_id = self.next_event_id();
            let workouts = entries
                .iter()
                .enumerate()
                .map(|(n, entry)| library_copy(entry, req.in_rotation, &event_id, n))
                .collect();
            self.edit(WorkoutsEdit::Add { workouts })?;
        }
        Ok(AddLibraryTemplatesResponse {})
    }

    /// A ready-made plan as the rotation: its entries the user lacks are
    /// copied in, then the user's workout for each entry goes first, in the
    /// plan's order, as the rotation, and every other workout after it (the
    /// old rotation first) as a reserve. One program edit; nothing is
    /// deleted.
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
            .filter(|id| !has_library_entry(&self.account.program, id))
            .cloned()
            .collect();
        let entries = library_entries(&missing)?;
        if !entries.is_empty() {
            let event_id = self.next_event_id();
            let workouts = entries
                .iter()
                .enumerate()
                .map(|(n, entry)| library_copy(entry, false, &event_id, n))
                .collect();
            self.edit(WorkoutsEdit::Add { workouts })?;
        }
        let workouts = &self.account.program.workouts;
        let mut rotation: Vec<String> = Vec::with_capacity(plan.library_ids.len());
        for id in &plan.library_ids {
            // One already in the rotation before any other copied from it.
            let from = |w: &&WorkoutDef| w.from_library == *id;
            let mine = workouts
                .iter()
                .filter(from)
                .find(|w| w.rotation && !rotation.contains(&w.id))
                .or_else(|| {
                    workouts
                        .iter()
                        .filter(from)
                        .find(|w| !rotation.contains(&w.id))
                })
                .ok_or_else(|| CoreError::NotFound(format!("no workout for {id:?}")))?;
            rotation.push(mine.id.clone());
        }
        let rest = workouts
            .iter()
            .filter(|w| w.rotation)
            .chain(workouts.iter().filter(|w| !w.rotation))
            .filter(|w| !rotation.contains(&w.id))
            .map(|w| w.id.clone());
        let workout_ids: Vec<String> = rotation.iter().cloned().chain(rest).collect();
        self.edit(WorkoutsEdit::Reorder {
            workout_ids,
            rotation_count: Some(rotation.len() as i32),
        })?;
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
        // Planned by `Call::add_exercises`; one reaching here has none.
        M::AddExercises(r) => Fact::ExercisesAdded(ExercisesAdded {
            workout_id: r.workout_id,
            exercises: r.exercises,
            ..Default::default()
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
}

impl<'a> View<'a> {
    pub fn new(account: &'a Account, now: i64) -> Self {
        Self { account, now }
    }

    fn program(&self) -> &'a Program {
        &self.account.program
    }

    /// "Save these lifts as a template?" for a workout: the lifts with a
    /// done working set, in workout order, unless they are the ones of the
    /// template it started from. None when nothing was done, or the
    /// template it started from is gone.
    fn template_offer(&self, record: &WorkoutRecord) -> Option<TemplateOffer> {
        let mut exercises: Vec<String> = Vec::new();
        for set in &record.proposed_sets {
            let done = record
                .completed_sets
                .iter()
                .any(|c| c.proposed_set_id == set.id);
            if done && !set.warmup && !set.cancelled && !exercises.contains(&set.exercise) {
                exercises.push(set.exercise.clone());
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
        let template = self.program().workout(template_id)?;
        let planned: BTreeSet<&String> = template.exercises.iter().collect();
        let same =
            planned.len() == exercises.len() && exercises.iter().all(|e| planned.contains(e));
        (!same).then(|| TemplateOffer {
            template_id: template.id.clone(),
            template_name: template.name.clone(),
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
                lift.estimated_max_after = planner
                    .walk(&lift.exercise)
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
            .map(|s| s.exercise.clone())
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
            exercises: self
                .with_estimated_max(compute_exercise_progress(&finished, self.program())),
        }
    }

    /// Each progress point gets the max the walk had after its session.
    fn with_estimated_max(&self, mut series: Vec<ExerciseProgress>) -> Vec<ExerciseProgress> {
        let planner = Planner::new(self.account, self.now);
        for progress in &mut series {
            let maxes: HashMap<String, f32> = planner
                .walk(&progress.exercise)
                .points
                .into_iter()
                .collect();
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
    /// program's default).
    pub fn exercise_plan(&self, exercise: &str, budget_minutes: i32) -> ExercisePlan {
        let planner = Planner::new(self.account, self.now);
        let decision = planner
            .workout(&[exercise.to_string()], &[], budget_minutes)
            .pop()
            .unwrap_or_default();
        planner.view(decision)
    }

    /// `exercises` planned at now as one workout in `budget_minutes` (0 =
    /// the program's default): what starting a template of them would
    /// record.
    pub fn template_plan(&self, exercises: &[String], budget_minutes: i32) -> TemplatePlan {
        self.plan_template(
            &Planner::new(self.account, self.now),
            exercises,
            budget_minutes,
        )
    }

    fn plan_template(
        &self,
        planner: &Planner,
        exercises: &[String],
        budget_minutes: i32,
    ) -> TemplatePlan {
        let lifts = known_exercises(planner.program(), exercises);
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
    /// planned at now in `budget_minutes` (0 = the program's default).
    pub fn home(&self, budget_minutes: i32) -> GetHomeResponse {
        let program = self.program();
        let planner = Planner::new(self.account, self.now);
        let budget = planner.budget(budget_minutes);
        let plans = program
            .exercises
            .iter()
            .filter_map(|e| {
                planner
                    .workout(std::slice::from_ref(&e.key), &[], budget)
                    .pop()
            })
            .map(|decision| planner.view(decision))
            .collect();
        let volume = muscle_volume(program, &self.account.workouts, self.now);
        let muscle_recovery = per_muscle_recovery(program, &self.account.workouts);
        let recovery = muscle_recovery
            .iter()
            .map(|entry| MuscleRecoveryStatus {
                muscle: entry.muscle.to_proto() as i32,
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
        let suggestion =
            suggest_template(program, &volume, &muscle_recovery, self.now, &last_started);
        // The library entries the user does not have, for the check's
        // additions.
        let addable: Vec<LibraryTemplate> = crate::template_library::library()
            .iter()
            .filter(|e| !has_library_entry(program, &e.id))
            .cloned()
            .collect();
        let template_plans = program
            .workouts
            .iter()
            .map(|t| TemplatePlan {
                template_id: t.id.clone(),
                ..self.plan_template(&planner, &t.exercises, budget)
            })
            .collect();

        GetHomeResponse {
            onboarded: self.account.onboarded
                || !program.workouts.is_empty()
                || !self.account.workouts.is_empty(),
            plans,
            template_plans,
            budget_minutes: budget,
            active_workout_id: self.account.active_workout_id.clone(),
            volume,
            recovery,
            rotation_check: Some(rotation_check(program, &addable)),
            addable_library_ids: addable.iter().map(|e| e.id.clone()).collect(),
            current_plan_id: current_plan(program)
                .map(|p| p.id.clone())
                .unwrap_or_default(),
            suggested_template_id: suggestion
                .as_ref()
                .map(|s| s.template_id.clone())
                .unwrap_or_default(),
            suggestion_reason: suggestion.map(|s| s.reason),
            templates: program.workouts.iter().map(template_of).collect(),
            program: Some(self.program_summary()),
        }
    }

    pub fn get_starting_weights(
        &self,
        req: GetStartingWeightsRequest,
    ) -> Result<GetStartingWeightsResponse, CoreError> {
        let unit = crate::weight_units::unit_from_proto(req.unit);
        let steps = (0..=100)
            .map(|step| StartingWeightsStep {
                weights: exercise_weights(self.program(), step as f32 / 100.0, unit),
            })
            .collect();
        Ok(GetStartingWeightsResponse { steps })
    }

    pub fn list_template_library(&self) -> ListTemplateLibraryResponse {
        ListTemplateLibraryResponse {
            templates: crate::template_library::library().to_vec(),
            plans: crate::template_library::plans().to_vec(),
        }
    }

    pub fn get_settings(&self) -> GetSettingsResponse {
        GetSettingsResponse {
            settings: self.account.settings.clone(),
        }
    }

    // ── The program ──

    /// The program that plans, in brief.
    pub fn program_summary(&self) -> ProgramSummary {
        match self.account.programs.last() {
            Some(version) => version_summary(version),
            None => ProgramSummary {
                name: Program::builtin().name.clone(),
                author: "builtin".into(),
                ..Default::default()
            },
        }
    }

    pub fn get_program(&self) -> GetProgramResponse {
        let versions = &self.account.programs;
        GetProgramResponse {
            summary: Some(self.program_summary()),
            program_json: self.program().to_json(),
            history: versions.iter().rev().skip(1).map(version_summary).collect(),
            guide: GUIDE.to_string(),
        }
    }

    pub fn get_program_version(
        &self,
        req: GetProgramVersionRequest,
    ) -> Result<GetProgramVersionResponse, CoreError> {
        let version = self
            .account
            .programs
            .iter()
            .find(|v| v.id == req.id)
            .ok_or_else(|| CoreError::NotFound("No such program".into()))?;
        Ok(GetProgramVersionResponse {
            summary: Some(version_summary(version)),
            program_json: version.program.to_json(),
        })
    }

    /// A draft's problems, the account's own included (an exercise it has
    /// history for, left out).
    pub fn validate_program(
        &self,
        req: ValidateProgramRequest,
    ) -> Result<ValidateProgramResponse, CoreError> {
        let (program, mut problems) = program::validate(&req.program_json);
        if let Some(program) = &program {
            problems.extend(program::validate_for_account(
                program,
                &self.account.exercises_used(),
            ));
        }
        Ok(ValidateProgramResponse {
            problems: problems.iter().map(problem_proto).collect(),
        })
    }

    pub fn simulate_program(
        &self,
        req: SimulateProgramRequest,
    ) -> Result<SimulateProgramResponse, CoreError> {
        Ok(crate::simulate::simulate(self.account, self.now, &req))
    }

    /// The program's exercises as every screen shows them, and the plates.
    pub fn list_exercises(&self) -> ListExercisesResponse {
        let program = self.program();
        let plates = &program.equipment.plates;
        ListExercisesResponse {
            exercises: program
                .exercises
                .iter()
                .map(|e| exercise_info(program, e))
                .collect(),
            lb: Some(PlateProfile {
                bar: plates.bar.lb,
                plates: plates.lb.clone(),
            }),
            kg: Some(PlateProfile {
                bar: plates.bar.kg,
                plates: plates.kg.clone(),
            }),
        }
    }
}

/// An exercise as every screen shows it.
pub fn exercise_info(program: &Program, e: &crate::program::ExerciseDef) -> ExerciseInfo {
    ExerciseInfo {
        key: e.key.clone(),
        name: e.name.clone(),
        short_name: e.short_name.clone(),
        equipment: e.equipment.to_proto() as i32,
        muscles: e.muscles.iter().map(|m| m.to_proto() as i32).collect(),
        description: e.description.clone(),
        class_name: e.class.clone(),
        progression: program.progression_name(&e.key).to_string(),
    }
}

fn version_summary(version: &ProgramVersion) -> ProgramSummary {
    ProgramSummary {
        id: version.id.clone(),
        name: version.program.name.clone(),
        author: version.author.clone(),
        note: version.note.clone(),
        set_at: version.at,
    }
}

pub fn problem_proto(p: &Problem) -> ProgramProblem {
    ProgramProblem {
        path: p.path.clone(),
        message: p.message.clone(),
        error: p.error,
    }
}

fn problem_text(p: &Problem) -> String {
    if p.path.is_empty() {
        p.message.clone()
    } else {
        format!("{}: {}", p.path, p.message)
    }
}

/// One of the program's workouts as the API shows it.
pub fn template_of(w: &WorkoutDef) -> WorkoutTemplate {
    WorkoutTemplate {
        id: w.id.clone(),
        name: w.name.clone(),
        exercises: w.exercises.clone(),
        in_rotation: w.rotation,
        origin_library_id: w.from_library.clone(),
        notes: w.notes.clone(),
    }
}

/// A library entry as one of the program's workouts, its id the `n`th
/// derived from the event that copies it.
fn library_copy(entry: &LibraryTemplate, rotation: bool, event_id: &str, n: usize) -> WorkoutDef {
    WorkoutDef {
        id: derived_id(event_id, n),
        name: entry.name.clone(),
        exercises: entry.exercises.clone(),
        rotation,
        notes: String::new(),
        from_library: entry.id.clone(),
    }
}

/// The user has a workout copied from library entry `id`.
fn has_library_entry(program: &Program, id: &str) -> bool {
    program.workouts.iter().any(|w| w.from_library == id)
}

/// The library entries for `ids`.
fn library_entries(ids: &[String]) -> Result<Vec<LibraryTemplate>, CoreError> {
    let library = crate::template_library::library();
    ids.iter()
        .map(|id| {
            library
                .iter()
                .find(|e| &e.id == id)
                .cloned()
                .ok_or_else(|| {
                    CoreError::InvalidArgument(format!("unknown library template {id:?}"))
                })
        })
        .collect()
}

/// The ready-made plan the rotation already is: the same workouts, each
/// copied from one of the plan's entries. The order is not compared (the
/// suggestion does not go through the rotation in order).
fn current_plan(program: &Program) -> Option<&'static LibraryPlan> {
    let rotation: Vec<&WorkoutDef> = program.workouts.iter().filter(|t| t.rotation).collect();
    crate::template_library::plans().iter().find(|plan| {
        let mut left: Vec<&String> = plan.library_ids.iter().collect();
        rotation.len() == left.len()
            && rotation
                .iter()
                .all(|t| match left.iter().position(|l| **l == t.from_library) {
                    Some(i) => {
                        left.remove(i);
                        true
                    }
                    None => false,
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

/// The exercises of a list the program knows, in order, each once: a
/// workout has a lift at most once.
fn known_exercises(program: &Program, keys: &[String]) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for key in keys {
        if program.knows(key) && !out.contains(key) {
            out.push(key.clone());
        }
    }
    out
}

/// The main lifts' starting weights at `strength` on the setup slider.
fn exercise_weights(
    program: &Program,
    strength: f32,
    unit: crate::weight_units::AppWeightUnit,
) -> Vec<ExerciseWeight> {
    crate::onboarding::starting_weights_for_strength(program, strength, unit)
        .into_iter()
        .map(|(exercise, weight_lb)| ExerciseWeight {
            exercise,
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
            "SetProgram" => set_program,
            "ResetProgram" => reset_program,
        }
        reads {
            "GetWorkout" => get_workout,
            "PreviewAdjustExercise" => preview_adjust_exercise,
            "GetWorkoutHeartRate" => get_workout_heart_rate,
            "GetStartingWeights" => get_starting_weights,
            "GetHome" => get_home,
            "GetTemplatePlan" => get_template_plan,
            "GetProgramVersion" => get_program_version,
            "ValidateProgram" => validate_program,
            "SimulateProgram" => simulate_program,
        }
        plain {
            "GetActiveWorkout" => get_active_workout,
            "ListWorkoutSummaries" => list_workout_summaries,
            "GetExerciseProgress" => get_exercise_progress,
            "ListTemplateLibrary" => list_template_library,
            "GetSettings" => get_settings,
            "GetProgram" => get_program,
            "ListExercises" => list_exercises,
        }
    })
}
