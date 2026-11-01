//! The account's API end to end, as the app uses it: onboarding → home →
//! start-from-template → complete → end → tracker advanced → next home
//! reflects it. Every test also checks that replaying the recorded events
//! rebuilds exactly the same account.

use schlift_core::account::{tracker_record, Account, CoreError};
use schlift_core::api::{Call, View};
use schlift_core::pb::workout_mutation::Mutation;
use schlift_core::pb::*;
use uuid::Uuid;

/// A plausible "now" for tests that read the clock.
const NOW: i64 = 1_800_000_000;

/// The phone, minus storage: an account, a clock, the event log and the
/// template library the server last sent.
struct App {
    account: Account,
    now: i64,
    log: Vec<Event>,
    library: Vec<LibraryTemplate>,
}

impl App {
    fn new() -> Self {
        Self {
            account: Account::default(),
            now: NOW,
            log: Vec::new(),
            library: schlift_core::template_library::library().to_vec(),
        }
    }

    fn view(&self) -> View<'_> {
        View::new(&self.account, self.now).with_library(&self.library)
    }

    fn call(&mut self) -> Recording<'_> {
        let id = Uuid::new_v4().to_string();
        Recording {
            call: Call::new(&mut self.account, self.now, id).with_library(&self.library),
            log: &mut self.log,
        }
    }
}

/// A call whose events land in the app's log when it's done.
struct Recording<'a> {
    call: Call<'a>,
    log: &'a mut Vec<Event>,
}

impl<'a> std::ops::Deref for Recording<'a> {
    type Target = Call<'a>;
    fn deref(&self) -> &Self::Target {
        &self.call
    }
}

impl std::ops::DerefMut for Recording<'_> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.call
    }
}

impl Drop for Recording<'_> {
    fn drop(&mut self) {
        self.log.append(&mut self.call.events);
    }
}

impl Drop for App {
    /// Replaying the log rebuilds the account exactly: the same ids, the
    /// same times, the same everything.
    fn drop(&mut self) {
        if std::thread::panicking() {
            return;
        }
        let seqs: Vec<i64> = self.log.iter().map(|e| e.seq).collect();
        let expected: Vec<i64> = (1..=self.log.len() as i64).collect();
        assert_eq!(seqs, expected, "the log has no gaps");
        assert_eq!(Account::fold(&self.log), self.account, "replay rebuilds it");
    }
}

fn onboard(app: &mut App, unit: WeightUnit) -> GetHomeResponse {
    app.call()
        .complete_onboarding(CompleteOnboardingRequest {
            body_weight_kg: 0.0,
            experience: ExperienceLevel::Unspecified as i32,
            unit: unit as i32,
            gender: 0,
            library_ids: vec![],
            strength: None,
            library_entries: vec![],
        })
        .unwrap()
        .home
        .unwrap()
}

fn home(app: &mut App) -> GetHomeResponse {
    app.view().get_home()
}

/// Stamp `last_performed_at` on the trackers so the next start prescribes
/// the ordinary block rather than a calibration ramp (a loaded exercise
/// never performed always calibrates). Weights and overrides are kept.
fn mark_performed(app: &mut App, exercises: &[Exercise], at: i64) {
    let trackers = exercises
        .iter()
        .map(|exercise| {
            let value = *exercise as i32;
            let mut state = app
                .account
                .trackers
                .get(&value)
                .copied()
                .unwrap_or_default();
            state.last_performed_at = at;
            tracker_record(value, &state)
        })
        .collect();
    app.call()
        .import_history(ImportHistory {
            workouts: vec![],
            trackers,
        })
        .unwrap();
}

const STRONGLIFTS_A: [Exercise; 3] = [Exercise::Squat, Exercise::BarbellRow, Exercise::BenchPress];

fn tracker(home: &GetHomeResponse, exercise: Exercise) -> ExerciseTracker {
    home.trackers
        .iter()
        .find(|t| t.exercise == exercise as i32)
        .cloned()
        .expect("every exercise has a tracker")
}

/// Complete every working set of a workout at exactly the given reps.
fn complete_all_working_sets(
    app: &mut App,
    workout_id: &str,
    sets: &[ProposedSet],
    reps_for: impl Fn(&ProposedSet) -> i32,
    weight_for: impl Fn(&ProposedSet) -> f32,
    start_ts: i64,
) -> i64 {
    let mut ts = start_ts;
    for set in sets.iter().filter(|s| !s.warmup && !s.cancelled) {
        app.call()
            .complete_set(CompleteSetRequest {
                workout_id: workout_id.to_string(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps_for(set),
                actual_weight: weight_for(set),
                completed_at: ts,
                effort: 0,
            })
            .unwrap();
        ts += 60;
    }
    ts
}

mod home_and_onboarding {
    use super::*;

    /// A brand-new user gets a complete home: a tracker for every exercise
    /// with a sane opener, ten volume rows, ten recovery rows, and
    /// onboarded = false so the app can route to setup.
    #[test]
    fn a_fresh_user_gets_a_full_home() {
        let mut app = App::new();
        let response = home(&mut app);

        assert!(!response.onboarded);
        assert!(response.templates.is_empty());
        assert_eq!(response.volume.len(), 10);
        assert_eq!(response.recovery.len(), 10);
        assert_eq!(
            response.trackers.len(),
            schlift_core::exercise_catalog::all_exercises().len()
        );

        let squat = tracker(&response, Exercise::Squat);
        assert_eq!(squat.working_weight, 45.0, "empty bar opener");
        assert_eq!((squat.rep_range_low, squat.rep_range_high), (5, 5));
        assert_eq!(squat.target_reps, 5, "five by five");
        assert!(squat.include_warmup);
        assert_eq!(squat.sets, 5);

        let raise = tracker(&response, Exercise::LateralRaise);
        assert_eq!(raise.working_weight, 20.0);
        assert!(!raise.include_warmup);
        assert_eq!(
            raise.equipment,
            EquipmentKind::Dumbbell as i32,
            "the picker's filter runs off this"
        );
        assert_eq!(raise.primary_muscle, MuscleGroup::Shoulders as i32);
    }

    /// Onboarding seeds the six defaults and bodyweight-scaled main lifts,
    /// and does nothing on a second call.
    #[test]
    fn onboarding_copies_the_chosen_library_entries() {
        let mut app = App::new();
        let home = app
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                body_weight_kg: 0.0,
                experience: ExperienceLevel::Unspecified as i32,
                unit: WeightUnit::Lb as i32,
                gender: 0,
                library_ids: vec!["stronglifts_a".into(), "butt_stuff".into()],
                strength: None,
                library_entries: vec![],
            })
            .unwrap()
            .home
            .unwrap();
        assert!(home.onboarded);
        let ids: Vec<&str> = home
            .templates
            .iter()
            .map(|t| t.library_id.as_str())
            .collect();
        assert_eq!(ids, vec!["stronglifts_a", "butt_stuff"]);
        assert_eq!(home.templates[0].name, "StrongLifts A");
        assert_eq!(
            home.templates[0].exercises,
            vec![
                Exercise::Squat as i32,
                Exercise::BarbellRow as i32,
                Exercise::BenchPress as i32
            ]
        );

        // An unknown id is refused outright.
        let mut app2 = App::new();
        let err = app2
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                body_weight_kg: 0.0,
                experience: 0,
                unit: WeightUnit::Lb as i32,
                gender: 0,
                library_ids: vec!["nope".into()],
                strength: None,
                library_entries: vec![],
            })
            .unwrap_err();
        assert!(matches!(err, CoreError::InvalidArgument(_)), "{err:?}");
    }

    #[test]
    fn library_lists_and_adds_without_duplicating() {
        let mut app = App::new();
        let library = schlift_core::template_library::load().unwrap();

        // Public listing mirrors the file, in order.
        let listed = app.view().list_template_library().templates;
        assert_eq!(listed.len(), library.len());
        assert_eq!(listed[0].id, library[0].id);
        assert!(listed.iter().any(|t| t.name == "Butt Stuff"));

        let home = onboard(&mut app, WeightUnit::Lb);
        let before = home.templates.len();
        assert!(home.templates.iter().all(|t| !t.library_id.is_empty()));

        // Adding one new and one already present adds exactly one.
        let already = home.templates[0].library_id.clone();
        let home = app
            .call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["butt_stuff".into(), already.clone()],
                entries: vec![],
            })
            .unwrap()
            .home
            .unwrap();
        assert_eq!(home.templates.len(), before + 1);
        let added = home.templates.last().unwrap();
        assert_eq!(added.library_id, "butt_stuff");
        assert_eq!(added.name, "Butt Stuff");

        assert!(added.coupled, "a library workout follows the library");

        // Saved unchanged it still follows; renamed it becomes the user's
        // own, and the library entry can be added again beside it.
        app.call()
            .save_template(SaveTemplateRequest {
                template: Some(added.clone()),
                ..Default::default()
            })
            .unwrap();
        assert!(app.account.template(&added.id).unwrap().coupled);
        let mut mine = added.clone();
        mine.name = "Cake Day".into();
        app.call()
            .save_template(SaveTemplateRequest {
                template: Some(mine),
                ..Default::default()
            })
            .unwrap();
        let home = self::home(&mut app);
        let renamed = home.templates.iter().find(|t| t.id == added.id).unwrap();
        assert_eq!(renamed.name, "Cake Day");
        assert!(!renamed.coupled && renamed.library_id.is_empty());
        let home = app
            .call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["butt_stuff".into()],
                entries: vec![],
            })
            .unwrap()
            .home
            .unwrap();
        assert_eq!(home.templates.len(), before + 2);

        // Deletion of the copy leaves the library untouched.
        app.call()
            .delete_template(DeleteTemplateRequest {
                template_id: renamed.id.clone(),
            })
            .unwrap();
        let listed = app.view().list_template_library().templates;
        assert_eq!(listed.len(), library.len());
    }

    #[test]
    fn onboarding_seeds_defaults_once() {
        let mut app = App::new();
        let response = app
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                body_weight_kg: 100.0,
                experience: ExperienceLevel::Intermediate as i32,
                unit: WeightUnit::Lb as i32,
                gender: Gender::Male as i32,
                library_ids: vec![],
                strength: None,
                library_entries: vec![],
            })
            .unwrap()
            .home
            .unwrap();

        assert!(response.onboarded);
        assert_eq!(response.templates.len(), 2);
        let names: Vec<&str> = response.templates.iter().map(|t| t.name.as_str()).collect();
        assert!(names.contains(&"StrongLifts A") && names.contains(&"StrongLifts B"));

        // 100 kg ≈ 220 lb × 0.95 squat ratio ≈ 210, snapped loadable.
        let squat = tracker(&response, Exercise::Squat);
        assert!(
            (squat.working_weight - 210.0).abs() <= 5.0,
            "bodyweight-scaled: {}",
            squat.working_weight
        );

        // Repeat call: idempotent, nothing duplicated.
        let again = onboard(&mut app, WeightUnit::Lb);
        assert_eq!(again.templates.len(), 2);
    }

    /// A kilogram user's weights land on the kilogram grid — the defect the
    /// old program-state unit read shipped for months.
    #[test]
    fn a_kg_user_gets_kg_loadable_weights() {
        let mut app = App::new();
        let response = app
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                body_weight_kg: 90.0,
                experience: ExperienceLevel::Intermediate as i32,
                unit: WeightUnit::Kg as i32,
                gender: 0,
                library_ids: vec![],
                strength: None,
                library_entries: vec![],
            })
            .unwrap()
            .home
            .unwrap();

        let squat = tracker(&response, Exercise::Squat);
        let kg = schlift_core::weight_units::pounds_to_kg(squat.working_weight);
        let on_grid = (kg / 2.5 - (kg / 2.5).round()).abs() < 0.01
            || ((kg - 20.0) / 2.5 - ((kg - 20.0) / 2.5).round()).abs() < 0.01;
        assert!(on_grid, "squat resolves to a loadable kg value: {kg} kg");
    }
}

mod templates {
    use super::*;

    pub(super) fn template(name: &str, exercises: &[Exercise]) -> WorkoutTemplate {
        WorkoutTemplate {
            name: name.to_string(),
            exercises: exercises.iter().map(|e| *e as i32).collect(),
            ..Default::default()
        }
    }

    #[test]
    fn save_edit_reorder_delete() {
        let mut app = App::new();

        let saved = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(template(
                    "Arms",
                    &[Exercise::BarbellCurl, Exercise::SkullCrusher],
                )),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        assert!(!saved.id.is_empty());

        // Edit keeps the id and order.
        let mut edited = saved.clone();
        edited.exercises.push(Exercise::HammerCurl as i32);
        let edited = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(edited),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        assert_eq!(edited.id, saved.id);
        assert_eq!(edited.exercises.len(), 3);

        let second = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(template("Legs", &[Exercise::Squat])),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();

        // Reorder: Legs first.
        app.call()
            .reorder_templates(ReorderTemplatesRequest {
                template_ids: vec![second.id.clone(), saved.id.clone()],
            })
            .unwrap();
        let listed = home(&mut app).templates;
        assert_eq!(listed[0].name, "Legs");
        assert_eq!(listed[1].name, "Arms");

        app.call()
            .delete_template(DeleteTemplateRequest {
                template_id: saved.id.clone(),
            })
            .unwrap();
        assert_eq!(home(&mut app).templates.len(), 1);
    }

    #[test]
    fn an_empty_template_is_rejected() {
        let mut app = App::new();
        let err = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(template("Empty", &[])),
                ..Default::default()
            })
            .unwrap_err();
        assert!(matches!(err, CoreError::InvalidArgument(_)), "{err:?}");
    }
}

mod template_workout_loop {
    use super::*;

    /// The whole point of the refactor, end to end: start from a template
    /// (server resolves weights + prescription + warmups), top the rep
    /// range, end the workout, and the next home shows the increased
    /// weight — on every template containing the exercise.
    #[test]
    fn topping_the_range_moves_the_weight_for_next_time() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        mark_performed(
            &mut app,
            &[Exercise::Squat, Exercise::Crunch, Exercise::CalfRaise],
            900,
        );
        // A barbell compound, a core move and a dumbbell move in one
        // template, so one session exercises every progression class.
        let lower = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(super::templates::template(
                    "Lower",
                    &[Exercise::Squat, Exercise::Crunch, Exercise::CalfRaise],
                )),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        let squat_before = tracker(&before, Exercise::Squat).working_weight;

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: 1_000,
                exercises: vec![],
                template_id: lower.id.clone(),
            })
            .unwrap();
        let workout = started.workout.unwrap();
        assert_eq!(workout.name, "Lower", "named after the template");

        // The squat block: tracker weight, prescription reps, a warmup
        // ladder (barbell compound). The crunch group: no warmups.
        let squat_sets: Vec<&ProposedSet> = started
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32)
            .collect();
        assert_eq!(squat_sets.iter().filter(|s| s.warmup).count(), 4);
        let squat_working: Vec<&&ProposedSet> = squat_sets.iter().filter(|s| !s.warmup).collect();
        assert_eq!(squat_working.len(), 5);
        assert!(squat_working
            .iter()
            .all(|s| s.target_weight == squat_before && s.target_reps == 5));
        assert!(started
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Crunch as i32)
            .all(|s| !s.warmup));

        // Clear everything at the top of each range.
        let home_ref = &before;
        let ts = complete_all_working_sets(
            &mut app,
            &workout.id,
            &started.proposed_sets,
            |set| {
                home_ref
                    .trackers
                    .iter()
                    .find(|t| t.exercise == set.exercise)
                    .map(|t| t.rep_range_high)
                    .unwrap()
            },
            |set| set.target_weight,
            2_000,
        );

        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            })
            .unwrap();

        let after = home(&mut app);
        let squat_after = tracker(&after, Exercise::Squat);
        assert_eq!(
            squat_after.working_weight,
            squat_before + 5.0,
            "one barbell step up"
        );
        assert_eq!(squat_after.target_reps, 5, "still five by five");
        assert_eq!(
            squat_after.last_performed_at, ts,
            "stamped with the end time"
        );

        // Bodyweight-free check on a dumbbell move from the same session:
        // calf raise topped its range too, so it took a dumbbell step.
        let calf_after = tracker(&after, Exercise::CalfRaise);
        assert_eq!(calf_after.working_weight, 25.0, "20 + one dumbbell step");
    }

    /// Every rep of a 5×5 adds a step: the barbell compounds progress
    /// linearly.
    #[test]
    fn clearing_a_five_by_five_adds_a_step() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        mark_performed(&mut app, &STRONGLIFTS_A, 900);
        let legs = before
            .templates
            .iter()
            .find(|t| t.name == "StrongLifts A")
            .unwrap();

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: 1_000,
                exercises: vec![],
                template_id: legs.id.clone(),
            })
            .unwrap();
        let workout = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &mut app,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            2_000,
        );
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            })
            .unwrap();

        let squat = tracker(&home(&mut app), Exercise::Squat);
        assert_eq!(squat.working_weight, 50.0, "45 + one bar step");
        assert_eq!(squat.target_reps, 5);
    }

    /// Clearing below the top of a rep range moves the rep target, not the
    /// weight.
    #[test]
    fn clearing_mid_range_moves_reps_not_weight() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        mark_performed(&mut app, &[Exercise::CalfRaise], 900);
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: 1_000,
                exercises: vec![Exercise::CalfRaise as i32],
                template_id: String::new(),
            })
            .unwrap();
        let workout = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &mut app,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            2_000,
        );
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            })
            .unwrap();

        let calf = tracker(&home(&mut app), Exercise::CalfRaise);
        assert_eq!(calf.working_weight, 20.0, "weight holds");
        assert_eq!(calf.target_reps, 9, "8 cleared → aim 9");
    }

    /// A re-fired EndWorkout must not advance a tracker twice.
    #[test]
    fn end_workout_is_idempotent() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        mark_performed(&mut app, &STRONGLIFTS_A, 900);
        let legs = before
            .templates
            .iter()
            .find(|t| t.name == "StrongLifts A")
            .unwrap();

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: 1_000,
                exercises: vec![],
                template_id: legs.id.clone(),
            })
            .unwrap();
        let workout = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &mut app,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            2_000,
        );

        for _ in 0..2 {
            app.call()
                .end_workout(EndWorkoutRequest {
                    workout_id: workout.id.clone(),
                    ended_at: ts,
                })
                .unwrap();
        }

        let after = home(&mut app);
        assert_eq!(
            tracker(&after, Exercise::Squat).working_weight,
            50.0,
            "advanced exactly once"
        );
    }

    /// A manual tracker write sticks and drives the next start.
    #[test]
    fn a_manual_override_drives_the_next_start() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        mark_performed(&mut app, &STRONGLIFTS_A, 900);
        let legs = before
            .templates
            .iter()
            .find(|t| t.name == "StrongLifts A")
            .unwrap();

        let set_response = app
            .call()
            .set_exercise_tracker(SetExerciseTrackerRequest {
                exercise: Exercise::Squat as i32,
                working_weight: 225.0,
                override_sets: 5,
                override_rep_low: 5,
                override_rep_high: 8,
                target_reps: 0,
            })
            .unwrap()
            .tracker
            .unwrap();
        assert_eq!(set_response.working_weight, 225.0);
        assert_eq!(set_response.sets, 5);
        assert!(set_response.overridden);

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: 1_000,
                exercises: vec![],
                template_id: legs.id.clone(),
            })
            .unwrap();
        let squat_working: Vec<&ProposedSet> = started
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32 && !s.warmup)
            .collect();
        assert_eq!(squat_working.len(), 5, "the override's set count");
        assert!(squat_working
            .iter()
            .all(|s| s.target_weight == 225.0 && s.target_reps == 5));
    }

    /// Time away reduces the weights offered at start — 90% after three
    /// weeks —
    /// without ever writing the reduction to the tracker.
    #[test]
    fn a_layoff_reduces_the_start_weight_only() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        mark_performed(&mut app, &STRONGLIFTS_A, 900_000);
        let legs = before
            .templates
            .iter()
            .find(|t| t.name == "StrongLifts A")
            .unwrap();
        let day = 24 * 3600;
        let long_ago = 1_000_000;

        app.call()
            .set_exercise_tracker(SetExerciseTrackerRequest {
                exercise: Exercise::Squat as i32,
                working_weight: 200.0,
                override_sets: 0,
                override_rep_low: 0,
                override_rep_high: 0,
                target_reps: 0,
            })
            .unwrap();
        // Backdate the squat's last performance by writing a finished
        // session through the real loop at `long_ago`.
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: long_ago,
                exercises: vec![],
                template_id: legs.id.clone(),
            })
            .unwrap();
        let first = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &mut app,
            &first.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            long_ago + 60,
        );
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: first.id.clone(),
                ended_at: ts,
            })
            .unwrap();

        let mid = home(&mut app);
        let squat_weight = tracker(&mid, Exercise::Squat).working_weight;
        assert_eq!(squat_weight, 205.0, "a cleared 5×5 adds a step");

        // 30 days later: the offered weight is 90%, snapped; the tracker
        // itself is untouched.
        let resumed = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: ts + 30 * day,
                exercises: vec![],
                template_id: legs.id.clone(),
            })
            .unwrap();
        let offered = resumed
            .proposed_sets
            .iter()
            .find(|s| s.exercise == Exercise::Squat as i32 && !s.warmup)
            .unwrap()
            .target_weight;
        assert_eq!(
            offered,
            schlift_core::weight_units::snap_loadable_lb(
                184.5,
                schlift_core::weight_units::AppWeightUnit::Lb
            ),
            "90% after three weeks away"
        );
        assert_eq!(
            tracker(&home(&mut app), Exercise::Squat).working_weight,
            205.0,
            "looking never writes"
        );
    }

    /// The suggestion points at the template covering the most-behind
    /// muscles, and names them.
    #[test]
    fn the_suggestion_chases_the_deficit() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        mark_performed(&mut app, &STRONGLIFTS_A, NOW - 7200);
        let legs = before
            .templates
            .iter()
            .find(|t| t.name == "StrongLifts A")
            .unwrap();

        // Train legs now; every other muscle is behind.
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: String::new(),
                started_at: NOW - 3600,
                exercises: vec![],
                template_id: legs.id.clone(),
            })
            .unwrap();
        let workout = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &mut app,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            NOW - 3000,
        );
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            })
            .unwrap();

        let after = home(&mut app);
        assert!(!after.suggested_template_id.is_empty());
        let suggested = after
            .templates
            .iter()
            .find(|t| t.id == after.suggested_template_id)
            .unwrap();
        assert_ne!(suggested.name, "StrongLifts A", "it was just trained");
        assert!(!after.suggestion_reason.is_empty());

        // Volume moved: quads got credited.
        let quads = after
            .volume
            .iter()
            .find(|v| v.muscle == MuscleGroup::Quads as i32)
            .unwrap();
        assert!(quads.completed_sets_7d > 0.0);
    }
}

mod calibration_and_effort {
    use super::*;

    fn mutation_at(m: workout_mutation::Mutation, at: i64) -> WorkoutMutation {
        WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: at,
            mutation: Some(m),
        }
    }

    fn apply(app: &mut App, mutations: Vec<WorkoutMutation>) -> GetWorkoutResponse {
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest { mutations })
            .unwrap()
            .workout_state
            .unwrap()
    }

    fn start(app: &mut App, exercises: &[Exercise]) -> StartWorkoutResponse {
        app.call()
            .start_workout(StartWorkoutRequest {
                name: "Cal".to_string(),
                started_at: 1_000,
                exercises: exercises.iter().map(|e| *e as i32).collect(),
                template_id: String::new(),
            })
            .unwrap()
    }

    fn complete(set: &ProposedSet, at: i64, reps: i32) -> WorkoutMutation {
        mutation_at(
            Mutation::CompleteSet(CompleteSetRequest {
                workout_id: set.workout_id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps,
                actual_weight: set.target_weight,
                completed_at: at,
                effort: 0,
            }),
            at,
        )
    }

    /// The onboarding seed is not a performance: the first session of a
    /// seeded barbell lift is one calibration rung at 60% of the seed,
    /// snapped — no warmup ladder, no working sets yet.
    #[test]
    fn a_seeded_barbell_lift_opens_its_ramp_at_sixty_percent() {
        let mut app = App::new();
        let seeded = app
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                body_weight_kg: 0.0,
                experience: 0,
                unit: WeightUnit::Lb as i32,
                gender: 0,
                library_ids: vec![],
                strength: Some(0.5),
                library_entries: vec![],
            })
            .unwrap()
            .home
            .unwrap();
        assert_eq!(
            tracker(&seeded, Exercise::Squat).working_weight,
            180.0,
            "the seed"
        );

        let started = start(&mut app, &[Exercise::Squat]);
        let squat: Vec<&ProposedSet> = started
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32)
            .collect();
        assert_eq!(squat.len(), 1, "one rung, nothing else");
        let rung = squat[0];
        assert!(rung.calibration);
        assert!(!rung.warmup);
        assert_eq!(rung.target_reps, 5);
        assert_eq!(rung.target_weight, 110.0, "60% of 180 snapped loadable");
        assert_eq!((rung.rest_after_success, rung.rest_after_failure), (90, 90));
        // The home still says 180: calibration never writes the tracker.
        assert_eq!(
            tracker(&home(&mut app), Exercise::Squat).working_weight,
            180.0
        );
    }

    /// A pull-up has no weight to find.
    /// The first-time "I lift X", before any rung: the ramp gives way to
    /// the warmup ladder and the full working sets at X.
    #[test]
    fn a_weight_given_up_front_skips_the_ramp() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let workout_id = started.workout.unwrap().id;
        let state = apply(
            &mut app,
            vec![mutation_at(
                Mutation::AdjustExerciseWeight(AdjustExerciseWeightRequest {
                    workout_id: workout_id.clone(),
                    exercise: Exercise::Squat as i32,
                    working_weight: 135.0,
                    ..Default::default()
                }),
                1_050,
            )],
        );
        let squat: Vec<&ProposedSet> = state
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32)
            .collect();
        assert!(squat.iter().all(|s| !s.calibration), "no ramp left");
        assert!(squat.iter().any(|s| s.warmup), "a ladder up to it");
        let working: Vec<_> = squat.iter().filter(|s| !s.warmup).collect();
        assert_eq!(working.len(), 5);
        assert!(working
            .iter()
            .all(|s| s.target_weight == 135.0 && s.target_reps == 5));
    }

    #[test]
    fn bodyweight_never_calibrates() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::PullUp]);
        assert_eq!(started.proposed_sets.len(), 3);
        assert!(started.proposed_sets.iter().all(|s| !s.calibration));
    }

    /// The whole ramp through the real handlers and persistence: a full
    /// rung climbs, a miss settles the working sets at 90% of the heaviest
    /// full rung, and EndWorkout writes the found weight to the tracker with
    /// the session stamped as performed.
    #[test]
    fn the_ramp_finds_a_working_weight_and_the_tracker_keeps_it() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat, Exercise::Crunch]);
        let workout_id = started.workout.unwrap().id;
        let rung1 = started.proposed_sets[0].clone();
        assert!(rung1.calibration);
        assert_eq!(rung1.target_weight, 45.0, "no seed: the empty bar");
        assert_eq!(rung1.target_reps, 5);

        // All five on the rung: the next one is spliced in.
        let state = apply(&mut app, vec![complete(&rung1, 1_100, 5)]);
        assert_eq!(
            state.completed_sets[0].rest_until, 1_190,
            "a rung rests its own 90 s"
        );
        let rung2 = state.proposed_sets[1].clone();
        assert!(rung2.calibration, "a full rung climbs");
        assert_eq!(rung2.target_weight, 50.0, "45 + one bar step");
        assert_eq!(
            state.proposed_sets[2].exercise,
            Exercise::Crunch as i32,
            "spliced in ahead of the next exercise"
        );

        // Four on the second rung: the ramp ends under it.
        let state = apply(&mut app, vec![complete(&rung2, 1_200, 4)]);
        let working: Vec<ProposedSet> = state
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32 && !s.calibration)
            .cloned()
            .collect();
        assert_eq!(working.len(), 5, "the full 5×5");
        assert!(working
            .iter()
            .all(|s| s.target_weight == 45.0 && s.target_reps == 5));

        let mut done: Vec<WorkoutMutation> = working
            .iter()
            .enumerate()
            .map(|(n, s)| complete(s, 1_400 + 200 * n as i64, 5))
            .collect();
        done.push(mutation_at(
            Mutation::EndWorkout(EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ended_at: 2_500,
            }),
            2_500,
        ));
        apply(&mut app, done);

        let squat = tracker(&home(&mut app), Exercise::Squat);
        assert_eq!(squat.working_weight, 50.0, "found at 45, cleared: +5");
        assert_eq!(squat.target_reps, 5);
        assert_eq!(
            squat.last_performed_at, 2_500,
            "now performed: no more ramps"
        );

        let stored = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: workout_id.clone(),
            })
            .unwrap();
        assert_eq!(
            stored
                .proposed_sets
                .iter()
                .filter(|s| s.calibration)
                .count(),
            2
        );
    }
}

mod batches {
    use super::*;

    fn mutation(m: workout_mutation::Mutation) -> WorkoutMutation {
        WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: 0,
            mutation: Some(m),
        }
    }

    /// Bail-out end to end: complete one set at target, remove the
    /// exercise, end the workout — all through the queue. The tracker must
    /// HOLD: no rep advance (the shrunk plan wasn't cleared) and no miss.
    /// Pins both the bail outcome and the retention of cancelled rows
    /// through the load→persist round trip.
    #[test]
    fn removing_an_exercise_mid_session_holds_the_tracker() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        let raise_before = tracker(&before, Exercise::LateralRaise);

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: "Bail".to_string(),
                started_at: 1_000,
                exercises: vec![Exercise::LateralRaise as i32],
                template_id: String::new(),
            })
            .unwrap();
        let workout_id = started.workout.unwrap().id;
        let first_set = started
            .proposed_sets
            .iter()
            .find(|s| !s.warmup)
            .unwrap()
            .clone();

        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![
                    mutation(Mutation::CompleteSet(CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: first_set.id.clone(),
                        actual_reps: first_set.target_reps,
                        actual_weight: first_set.target_weight,
                        completed_at: 1_100,
                        effort: 0,
                    })),
                    mutation(Mutation::RemoveExercise(RemoveExerciseRequest {
                        workout_id: workout_id.clone(),
                        exercise: Exercise::LateralRaise as i32,
                    })),
                ],
            })
            .unwrap();
        // A separate batch, so the bail signal must survive its own
        // load→persist round trip before the workout ends.
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(Mutation::EndWorkout(EndWorkoutRequest {
                    workout_id: workout_id.clone(),
                    ended_at: 2_000,
                }))],
            })
            .unwrap();

        let after = home(&mut app);
        let raise_after = tracker(&after, Exercise::LateralRaise);
        assert_eq!(
            raise_after.working_weight, raise_before.working_weight,
            "a bail holds the weight"
        );
        assert_eq!(
            raise_after.target_reps, raise_before.target_reps,
            "a bail does not advance the rep target"
        );
    }

    /// A mutation that can never apply must be consumed, not retried: one
    /// poison mutation would otherwise wedge every completion queued
    /// behind it, permanently.
    #[test]
    fn a_poison_mutation_is_skipped_and_the_rest_of_the_batch_applies() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: "Poison".to_string(),
                started_at: 1_000,
                exercises: vec![Exercise::LateralRaise as i32],
                template_id: String::new(),
            })
            .unwrap();
        let workout_id = started.workout.unwrap().id;
        let first_set = started
            .proposed_sets
            .iter()
            .find(|s| !s.warmup)
            .unwrap()
            .id
            .clone();

        let response = app
            .call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![
                    // Rejected by the weight range check.
                    mutation(Mutation::AdjustExerciseWeight(
                        AdjustExerciseWeightRequest {
                            workout_id: workout_id.clone(),
                            exercise: Exercise::LateralRaise as i32,
                            working_weight: -50.0,
                            target_reps: 0,
                        },
                    )),
                    mutation(Mutation::CompleteSet(CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: first_set.clone(),
                        actual_reps: 10,
                        actual_weight: 20.0,
                        completed_at: 1_100,
                        effort: 0,
                    })),
                ],
            })
            .unwrap();

        assert_eq!(
            response.applied_event_ids.len(),
            2,
            "the poison mutation is acked so the client evicts it"
        );
        let state = response.workout_state.unwrap();
        assert_eq!(
            state.completed_sets.len(),
            1,
            "the completion behind the poison mutation still applied"
        );
        assert!(
            state.proposed_sets.iter().all(|s| s.target_weight >= 0.0),
            "the rejected weight never landed"
        );
    }
}

mod lifting {
    use super::*;

    fn at(m: workout_mutation::Mutation, t: i64) -> WorkoutMutation {
        WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: t,
            mutation: Some(m),
        }
    }

    /// A fresh read of the workout.
    fn read(app: &mut App, workout_id: &str) -> GetWorkoutResponse {
        app.view()
            .get_workout(GetWorkoutRequest {
                workout_id: workout_id.to_string(),
            })
            .unwrap()
    }

    /// Start → LIFTING survives a round trip through the database, and the
    /// Done that ends it keeps the start.
    #[test]
    fn a_started_set_is_lifting_and_its_done_keeps_the_start() {
        let mut app = App::new();
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                name: "Lift".to_string(),
                started_at: 1_000,
                exercises: vec![Exercise::Squat as i32],
                template_id: String::new(),
            })
            .unwrap();
        let workout_id = started.workout.as_ref().unwrap().id.clone();
        let set = started
            .proposed_sets
            .iter()
            .find(|s| !s.warmup && !s.cancelled)
            .or_else(|| started.proposed_sets.first())
            .unwrap()
            .clone();

        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![at(
                    workout_mutation::Mutation::StartSet(StartSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: set.id.clone(),
                        started_at: 1_100,
                    }),
                    1_100,
                )],
            })
            .unwrap();

        let lifting = read(&mut app, &workout_id);
        let snap = lifting.state_snapshot.unwrap();
        assert_eq!(
            snap.state,
            WorkoutState::Lifting as i32,
            "persisted and reloaded"
        );
        assert_eq!(snap.display_set.unwrap().id, set.id);
        assert_eq!(snap.lifting_started_at, 1_100);

        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![at(
                    workout_mutation::Mutation::CompleteSet(CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: set.id.clone(),
                        actual_reps: set.target_reps,
                        actual_weight: set.target_weight,
                        completed_at: 1_140,
                        effort: 0,
                    }),
                    1_140,
                )],
            })
            .unwrap();

        let done = read(&mut app, &workout_id);
        let row = done
            .completed_sets
            .iter()
            .find(|c| c.proposed_set_id == set.id)
            .expect("done");
        assert_eq!(row.started_at, 1_100, "the start is kept on the done set");
        assert_ne!(
            done.state_snapshot.unwrap().state,
            WorkoutState::Lifting as i32,
            "Done ends the lifting"
        );
        assert!(done.workout.unwrap().lifting_set_id.is_empty());
    }
}

mod the_log {
    use super::*;
    use prost::Message;

    /// A write that fails records nothing and changes nothing.
    #[test]
    fn a_refused_write_leaves_no_trace() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Kg);
        let before = app.account.clone();
        let err = app
            .call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["butt_stuff".into(), "nope".into()],
                entries: vec![],
            })
            .unwrap_err();
        assert!(matches!(err, CoreError::InvalidArgument(_)));
        assert_eq!(app.account, before, "not even the valid half");
        assert_eq!(app.log.len(), 1, "only the onboarding");
    }

    /// The app's way in: method name and proto bytes, both ways.
    #[test]
    fn calls_by_name_with_proto_bytes() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let template_id = app.account.templates[0].id.clone();
        let mut call = app.call();
        let bytes = schlift_core::api::call(
            &mut call,
            "StartWorkout",
            &StartWorkoutRequest {
                template_id,
                ..Default::default()
            }
            .encode_to_vec(),
        )
        .unwrap();
        let started = StartWorkoutResponse::decode(bytes.as_slice()).unwrap();
        assert_eq!(
            started.workout.unwrap().id,
            call.events[0].id,
            "the event's id"
        );
        assert_eq!(call.events.len(), 1);

        let home = GetHomeResponse::decode(
            schlift_core::api::call(&mut call, "GetHome", &[])
                .unwrap()
                .as_slice(),
        )
        .unwrap();
        assert_eq!(home.active_workout_id, started.id);
        assert_eq!(call.events.len(), 1, "reads record nothing");

        assert!(matches!(
            schlift_core::api::call(&mut call, "Nope", &[]),
            Err(CoreError::InvalidArgument(_))
        ));
    }

    /// Ending a workout clears the active one and is recorded once.
    #[test]
    fn ending_clears_the_active_workout() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                exercises: vec![Exercise::PullUp as i32],
                ..Default::default()
            })
            .unwrap();
        assert_eq!(
            app.view().get_active_workout().workout.unwrap().id,
            started.id
        );
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            })
            .unwrap();
        assert!(app.view().get_active_workout().workout.is_none());
        let finished = app.view().list_workouts().workouts;
        assert_eq!(finished.len(), 1);
        assert_eq!(finished[0].end_time, NOW, "ended at the event's time");
    }
}

mod starting_weights {
    use super::*;

    /// What the setup slider shows at a step is exactly what onboarding at
    /// that strength seeds.
    #[test]
    fn the_slider_shows_what_onboarding_seeds() {
        for (unit, step) in [
            (WeightUnit::Lb, 0),
            (WeightUnit::Kg, 37),
            (WeightUnit::Lb, 100),
        ] {
            let mut app = App::new();
            let shown = app
                .view()
                .get_starting_weights(GetStartingWeightsRequest { unit: unit as i32 })
                .unwrap()
                .steps;
            assert_eq!(shown.len(), 101);
            let home = app
                .call()
                .complete_onboarding(CompleteOnboardingRequest {
                    unit: unit as i32,
                    strength: Some(step as f32 / 100.0),
                    ..Default::default()
                })
                .unwrap()
                .home
                .unwrap();
            for w in &shown[step].weights {
                let tracker = tracker(&home, w.exercise());
                assert_eq!(
                    tracker.working_weight,
                    w.weight_lb,
                    "{:?} at {step}",
                    w.exercise()
                );
            }
        }
    }
}

mod library_coupling {
    use super::*;

    fn stronglifts_a(app: &mut App) -> WorkoutTemplate {
        onboard(app, WeightUnit::Lb)
            .templates
            .into_iter()
            .find(|t| t.library_id == "stronglifts_a")
            .unwrap()
    }

    /// The server changes a default: the next home shows it, a start runs
    /// it, and the start's event carries it — so the log replays the same
    /// without the library (App's Drop checks that).
    #[test]
    fn a_library_change_reaches_coupled_templates() {
        let mut app = App::new();
        let template = stronglifts_a(&mut app);
        assert!(template.coupled);

        let entry = app
            .library
            .iter_mut()
            .find(|e| e.id == "stronglifts_a")
            .unwrap();
        entry.name = "StrongLifts A+".into();
        entry.exercises = vec![Exercise::Squat as i32, Exercise::Deadlift as i32];

        let shown = home(&mut app)
            .templates
            .into_iter()
            .find(|t| t.id == template.id)
            .unwrap();
        assert_eq!(shown.name, "StrongLifts A+");
        assert_eq!(shown.exercises.len(), 2);

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                template_id: template.id.clone(),
                ..Default::default()
            })
            .unwrap();
        let exercises: std::collections::BTreeSet<i32> =
            started.proposed_sets.iter().map(|s| s.exercise).collect();
        assert_eq!(
            exercises,
            [Exercise::Squat as i32, Exercise::Deadlift as i32].into()
        );
        let workout = started.workout.unwrap();
        assert_eq!(workout.template_id, template.id, "recorded against it");
        assert_eq!(
            workout.name, "StrongLifts A+",
            "under the library's name of now"
        );
    }

    /// Clone makes it the user's own in place: same id (its history stays
    /// with it), the library's exercises of the moment, and library changes
    /// no longer reach it.
    #[test]
    fn clone_keeps_the_id_and_stops_following() {
        let mut app = App::new();
        let template = stronglifts_a(&mut app);
        let cloned = app
            .call()
            .clone_template(CloneTemplateRequest {
                template_id: template.id.clone(),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        assert_eq!(cloned.id, template.id);
        assert!(!cloned.coupled && cloned.library_id.is_empty());
        assert_eq!(cloned.exercises, template.exercises);

        app.library
            .iter_mut()
            .find(|e| e.id == "stronglifts_a")
            .unwrap()
            .exercises = vec![Exercise::Deadlift as i32];
        let shown = home(&mut app)
            .templates
            .into_iter()
            .find(|t| t.id == template.id)
            .unwrap();
        assert_eq!(shown.exercises, template.exercises, "its own now");
    }

    /// The library moved on; the user edits the template back to the copy
    /// stored when they added it. That is a change to what they saw, so it
    /// becomes theirs rather than following the library again.
    #[test]
    fn an_edit_back_to_the_stored_copy_is_kept() {
        let mut app = App::new();
        let template = stronglifts_a(&mut app);
        app.library
            .iter_mut()
            .find(|e| e.id == "stronglifts_a")
            .unwrap()
            .exercises = vec![Exercise::Deadlift as i32];

        let saved = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(template.clone()),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        assert!(!saved.coupled, "the user's own now");
        let shown = home(&mut app)
            .templates
            .into_iter()
            .find(|t| t.id == template.id)
            .unwrap();
        assert_eq!(shown.exercises, template.exercises, "the edit stands");
    }

    /// A default the server drops keeps working from what was stored.
    #[test]
    fn a_dropped_entry_falls_back_to_the_stored_copy() {
        let mut app = App::new();
        let template = stronglifts_a(&mut app);
        app.library.retain(|e| e.id != "stronglifts_a");
        let shown = home(&mut app)
            .templates
            .into_iter()
            .find(|t| t.id == template.id)
            .unwrap();
        assert_eq!(shown.name, template.name);
        assert_eq!(shown.exercises, template.exercises);
    }
}
