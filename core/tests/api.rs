//! The account's API end to end, as the app uses it: onboarding → home →
//! start → sets done → end → the next plan follows. Every test also checks
//! that replaying the recorded events rebuilds exactly the same account.

use schlift_core::account::{Account, CoreError};
use schlift_core::api::{Call, View};
use schlift_core::pb::workout_mutation::Mutation;
use schlift_core::pb::*;
use uuid::Uuid;

/// A plausible "now" for tests that read the clock.
const NOW: i64 = 1_800_000_000;
const DAY: i64 = 24 * 3600;

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
            unit: unit as i32,
            ..Default::default()
        })
        .unwrap()
        .home
        .unwrap()
}

fn home(app: &mut App) -> GetHomeResponse {
    app.view().get_home(GetHomeRequest::default()).unwrap()
}

/// The lift's plan on its own at the app's now.
fn plan(app: &App, exercise: Exercise) -> ExerciseDecision {
    app.view()
        .exercise_plan(exercise, 0)
        .decision
        .expect("every plan has a decision")
}

fn kinds(d: &ExerciseDecision) -> Vec<PlanReasonKind> {
    d.reasons
        .iter()
        .map(|r| PlanReasonKind::try_from(r.kind).unwrap())
        .collect()
}

/// A finished session of one lift brought in by import: one working set per
/// entry of `reps`, each at `weight` against `target`, ending at `end`.
fn import_session(
    app: &mut App,
    exercise: Exercise,
    weight: f32,
    target: i32,
    reps: &[i32],
    end: i64,
) {
    let id = Uuid::new_v4().to_string();
    let mut workout = ImportedWorkout {
        workout: Some(Workout {
            id: id.clone(),
            name: "Imported".into(),
            start_time: end - 3600,
            end_time: end,
            ..Default::default()
        }),
        ..Default::default()
    };
    for (n, done) in reps.iter().enumerate() {
        let set_id = format!("{id}:{n}");
        workout.proposed_sets.push(ProposedSet {
            id: set_id.clone(),
            workout_id: id.clone(),
            workout_order: n as i32,
            exercise: exercise as i32,
            target_reps: target,
            target_weight: weight,
            rest_seconds: 120,
            ..Default::default()
        });
        workout.completed_sets.push(CompletedSet {
            id: format!("{set_id}:done"),
            workout_id: id.clone(),
            proposed_set_id: set_id,
            actual_reps: *done,
            actual_weight: weight,
            ended_at: end - 600 + n as i64 * 100,
            ..Default::default()
        });
    }
    app.call()
        .import_history(ImportHistory {
            workouts: vec![workout],
            starting_weights: vec![],
        })
        .unwrap();
}

fn start(app: &mut App, exercises: &[Exercise]) -> StartWorkoutResponse {
    app.call()
        .start_workout(StartWorkoutRequest {
            exercises: exercises.iter().map(|e| *e as i32).collect(),
            ..Default::default()
        })
        .unwrap()
}

fn working(sets: &[ProposedSet], exercise: Exercise) -> Vec<ProposedSet> {
    sets.iter()
        .filter(|s| s.exercise == exercise as i32 && !s.warmup && !s.calibration && !s.cancelled)
        .cloned()
        .collect()
}

/// Do every working set of a workout at the given reps, a minute apart from
/// `from`, then end it. Returns the end time.
fn finish(
    app: &mut App,
    started: &StartWorkoutResponse,
    reps_for: impl Fn(&ProposedSet) -> i32,
    from: i64,
) -> i64 {
    let mut ts = from;
    for set in started
        .proposed_sets
        .iter()
        .filter(|s| !s.warmup && !s.calibration)
    {
        app.call()
            .complete_set(CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps_for(set),
                actual_weight: set.target_weight,
                completed_at: ts,
            })
            .unwrap();
        ts += 60;
    }
    app.call()
        .end_workout(EndWorkoutRequest {
            workout_id: started.id.clone(),
            ended_at: ts,
        })
        .unwrap();
    ts
}

fn decision(started: &StartWorkoutResponse, exercise: Exercise) -> ExerciseDecision {
    started
        .exercise_logs
        .iter()
        .filter_map(|l| l.decision.clone())
        .find(|d| d.exercise == exercise as i32)
        .expect("the lift was planned")
}

const STRONGLIFTS_A: [Exercise; 3] = [Exercise::Squat, Exercise::BarbellRow, Exercise::BenchPress];

mod home_and_onboarding {
    use super::*;

    /// A brand-new user gets a complete home: a plan for every exercise,
    /// ten volume rows, ten recovery rows, the default budget, and
    /// onboarded = false so the app can route to setup.
    #[test]
    fn a_fresh_user_gets_a_full_home() {
        let mut app = App::new();
        let response = home(&mut app);

        assert!(!response.onboarded);
        assert!(response.templates.is_empty());
        assert_eq!(response.volume.len(), 10);
        assert_eq!(response.recovery.len(), 10);
        assert_eq!(response.budget_minutes, 60);
        assert_eq!(
            response.plans.len(),
            schlift_core::exercise_catalog::all_exercises().len()
        );

        let squat = plan(&app, Exercise::Squat);
        assert!(squat.calibration, "never done: a ramp");
        assert_eq!(squat.weight, 45.0, "from the empty bar");
        assert_eq!((squat.rep_low, squat.rep_high), (5, 8));
        assert!(squat.warmups);
        assert_eq!(
            kinds(&squat),
            vec![PlanReasonKind::FirstTime, PlanReasonKind::SetsFromTime]
        );

        let raise = response
            .plans
            .iter()
            .find(|p| p.decision.as_ref().unwrap().exercise == Exercise::LateralRaise as i32)
            .unwrap();
        assert_eq!(raise.decision.as_ref().unwrap().weight, 20.0);
        assert_eq!(
            raise.equipment,
            EquipmentKind::Dumbbell as i32,
            "the picker's filter runs off this"
        );
        assert_eq!(raise.primary_muscle, MuscleGroup::Shoulders as i32);
        assert_eq!(raise.last_performed_at, 0);
    }

    #[test]
    fn onboarding_copies_the_chosen_library_entries() {
        let mut app = App::new();
        let home = app
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                unit: WeightUnit::Lb as i32,
                library_ids: vec!["stronglifts_a".into(), "butt_stuff".into()],
                ..Default::default()
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
        assert_eq!(home.template_plans.len(), 2, "each template previewed");

        // An unknown id is refused outright.
        let mut app2 = App::new();
        let err = app2
            .call()
            .complete_onboarding(CompleteOnboardingRequest {
                unit: WeightUnit::Lb as i32,
                library_ids: vec!["nope".into()],
                ..Default::default()
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

    /// The strength slider's starting weights are recorded on the event, and
    /// a lift never done ramps from 60% of its own. A second onboarding
    /// copies nothing more and keeps them.
    #[test]
    fn onboarding_records_the_starting_weights_once() {
        let mut app = App::new();
        app.call()
            .complete_onboarding(CompleteOnboardingRequest {
                unit: WeightUnit::Lb as i32,
                strength: Some(0.5),
                ..Default::default()
            })
            .unwrap();
        let Some(event::Kind::CompleteOnboarding(recorded)) = &app.log[0].kind else {
            panic!("onboarding recorded");
        };
        assert!(recorded
            .starting_weights
            .iter()
            .any(|w| w.exercise == Exercise::Squat as i32 && w.weight_lb == 180.0));

        let squat = plan(&app, Exercise::Squat);
        assert_eq!(squat.weight, 110.0, "60% of 180, loadable");
        assert_eq!(squat.reasons[0].before, 180.0);

        let again = onboard(&mut app, WeightUnit::Lb);
        assert_eq!(again.templates.len(), 2);
        assert_eq!(plan(&app, Exercise::Squat).weight, 110.0);
    }

    /// A kilogram user's weights land on the kilogram grid.
    #[test]
    fn a_kg_user_gets_kg_loadable_weights() {
        let mut app = App::new();
        app.call()
            .complete_onboarding(CompleteOnboardingRequest {
                unit: WeightUnit::Kg as i32,
                strength: Some(0.5),
                ..Default::default()
            })
            .unwrap();
        let kg = schlift_core::weight_units::pounds_to_kg(plan(&app, Exercise::Squat).weight);
        let on_grid = ((kg - 20.0) / 2.5 - ((kg - 20.0) / 2.5).round()).abs() < 0.01;
        assert!(on_grid, "the ramp opens at a loadable kg value: {kg} kg");
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

mod the_walk {
    use super::*;

    /// Every rep hit: a rep more at the same weight next time, then past the
    /// top of the range a step up — through the real start, sets and end.
    #[test]
    fn a_hit_climbs_a_rep_then_steps_up() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(&mut app, Exercise::Squat, 200.0, 6, &[6, 6, 6], NOW - DAY);

        let squat = plan(&app, Exercise::Squat);
        assert_eq!(squat.weight, 200.0, "the last weight");
        assert_eq!(
            squat.reps,
            schlift_core::plan::reps_covered(squat.max, 200.0, squat.sets, false),
            "as many reps as the max covers over the planned sets"
        );
        assert_eq!(kinds(&squat)[0], PlanReasonKind::MaxUp);

        let mut reps = Vec::new();
        for n in 0..3 {
            let started = start(&mut app, &[Exercise::Squat]);
            let d = decision(&started, Exercise::Squat);
            assert_eq!(
                working(&started.proposed_sets, Exercise::Squat).len(),
                d.sets as usize
            );
            reps.push((d.weight, d.reps));
            app.now += 3600;
            let from = app.now - 1800;
            let ended = finish(&mut app, &started, |s| s.target_reps, from);
            assert!(plan(&app, Exercise::Squat).max > d.max, "session {n}");
            app.now = ended + 2 * DAY;
        }
        assert!(
            reps.windows(2)
                .all(|w| w[1].0 > w[0].0 || (w[1].0 == w[0].0 && w[1].1 == w[0].1 + 1)),
            "a rep a session, then a step: {reps:?}"
        );
    }

    /// A miss brings the max back to what the user showed.
    #[test]
    fn a_miss_resets_the_max() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::Squat,
            200.0,
            6,
            &[6, 6, 6],
            NOW - 3 * DAY,
        );
        let before = plan(&app, Exercise::Squat).max;
        import_session(&mut app, Exercise::Squat, 200.0, 7, &[7, 5, 4], NOW - DAY);
        let after = plan(&app, Exercise::Squat);
        assert_eq!(kinds(&after)[0], PlanReasonKind::MaxFromMiss);
        assert!(after.max < before);
        assert!(after.reps < 7 || after.weight < 200.0);
    }

    /// A re-fired EndWorkout changes nothing.
    #[test]
    fn end_workout_is_idempotent() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(&mut app, Exercise::Squat, 200.0, 6, &[6, 6, 6], NOW - DAY);
        let started = start(&mut app, &[Exercise::Squat]);
        let ended = finish(&mut app, &started, |s| s.target_reps, NOW + 60);
        let once = home(&mut app).plans;
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: ended + 500,
            })
            .unwrap();
        assert_eq!(home(&mut app).plans, once);
        assert_eq!(
            app.view().list_workouts().workouts[0].end_time,
            ended,
            "the first end stands"
        );
    }

    /// An override is planned as given, its sets kept by the budget, and the
    /// next plan carries on from it.
    #[test]
    fn an_override_is_a_new_start() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::Squat,
            300.0,
            6,
            &[6, 6, 6],
            NOW - 5 * DAY,
        );
        let shown = app
            .call()
            .set_override(SetOverrideRequest {
                exercise: Exercise::Squat as i32,
                weight: 225.0,
                reps: 5,
                sets: Some(4),
            })
            .unwrap()
            .plan
            .unwrap();
        assert!(shown.overridden);
        let d = shown.decision.unwrap();
        assert_eq!((d.weight, d.reps, d.sets), (225.0, 5, 4));
        assert_eq!(kinds(&d), vec![PlanReasonKind::UserSet]);
        assert_eq!(d.reasons[0].at, NOW);

        app.now += 60;
        let started = start(&mut app, &[Exercise::Squat, Exercise::BenchPress]);
        let squat = working(&started.proposed_sets, Exercise::Squat);
        assert_eq!(squat.len(), 4, "the override's sets");
        assert!(squat
            .iter()
            .all(|s| s.target_weight == 225.0 && s.target_reps == 5));
        assert!(started
            .proposed_sets
            .iter()
            .any(|s| s.exercise == Exercise::Squat as i32 && s.warmup));
        let ended = finish(&mut app, &started, |s| s.target_reps, NOW + 600);
        app.now = ended + DAY;
        let next = plan(&app, Exercise::Squat);
        assert_eq!((next.weight, next.reps), (225.0, 6), "a rep up from it");
        assert_eq!(kinds(&next)[0], PlanReasonKind::MaxUp);

        // Reps of 0 removes it.
        app.call()
            .set_override(SetOverrideRequest {
                exercise: Exercise::Squat as i32,
                ..Default::default()
            })
            .unwrap();
        assert!(app.account.overrides.is_empty());
    }

    /// Weeks away: the max is cut when the workout is planned.
    #[test]
    fn time_away_cuts_the_max() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::Squat,
            200.0,
            6,
            &[6, 6, 6],
            NOW - 45 * DAY,
        );
        let d = plan(&app, Exercise::Squat);
        assert_eq!(
            kinds(&d),
            vec![
                PlanReasonKind::MaxUp,
                PlanReasonKind::TimeOff,
                PlanReasonKind::SetsFromTime
            ]
        );
        assert_eq!(d.reasons[1].days_off, 45);
        assert!((d.max - d.reasons[1].before * 0.8).abs() < 1e-3);
        assert!(d.weight < 200.0);
    }

    /// The progress page's estimated max follows the walk.
    #[test]
    fn progress_shows_the_estimated_max() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::Squat,
            200.0,
            6,
            &[6, 6, 6],
            NOW - 3 * DAY,
        );
        import_session(&mut app, Exercise::Squat, 200.0, 7, &[7, 7, 7], NOW - DAY);
        let progress = app.view().get_exercise_progress();
        let squat = progress
            .exercises
            .iter()
            .find(|e| e.exercise == Exercise::Squat as i32)
            .unwrap();
        let maxes: Vec<f32> = squat.points.iter().map(|p| p.estimated_max).collect();
        assert_eq!(maxes.len(), 2);
        assert!(maxes[0] > 200.0 && maxes[1] > maxes[0], "{maxes:?}");
        assert_eq!(maxes[1], plan(&app, Exercise::Squat).max);
    }

    /// The suggestion turns from the template just trained to the other in
    /// rotation, and says what is still recovering.
    #[test]
    fn the_suggestion_chases_the_deficit() {
        let mut app = App::new();
        let before = onboard(&mut app, WeightUnit::Lb);
        for lift in STRONGLIFTS_A {
            import_session(&mut app, lift, 100.0, 5, &[5, 5, 5], NOW - 10 * DAY);
        }
        let legs = before
            .templates
            .iter()
            .find(|t| t.name == "StrongLifts A")
            .unwrap();
        app.now = NOW - 3600;
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                template_id: legs.id.clone(),
                ..Default::default()
            })
            .unwrap();
        finish(&mut app, &started, |s| s.target_reps, NOW - 3000);
        app.now = NOW;

        let after = home(&mut app);
        let suggested = after
            .templates
            .iter()
            .find(|t| t.id == after.suggested_template_id)
            .unwrap();
        assert_ne!(suggested.name, "StrongLifts A", "it was just trained");
        // The squat an hour ago rules quads out, and the reason says so.
        let reason = after.suggestion_reason.clone().expect("a reason");
        assert!(
            reason
                .recovering
                .iter()
                .any(|r| r.muscle == MuscleGroup::Quads as i32 && r.hours_remaining > 0),
            "{reason:?}"
        );
        let quads = after
            .volume
            .iter()
            .find(|v| v.muscle == MuscleGroup::Quads as i32)
            .unwrap();
        assert!(quads.completed_sets_7d > 0.0);
    }
}

mod budget {
    use super::*;

    fn sets(d: &[ExerciseDecision]) -> Vec<i32> {
        d.iter().map(|d| d.sets).collect()
    }

    /// Home's preview of a template is exactly what starting it then, in the
    /// same budget, records.
    #[test]
    fn home_preview_equals_a_start() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::Squat,
            200.0,
            6,
            &[6, 6, 6],
            NOW - 2 * DAY,
        );
        import_session(
            &mut app,
            Exercise::BenchPress,
            135.0,
            8,
            &[8, 7, 6],
            NOW - DAY,
        );
        let template = onboarded
            .templates
            .iter()
            .find(|t| t.library_id == "stronglifts_a")
            .unwrap()
            .clone();
        for budget in [0, 25, 45, 90] {
            let preview = app
                .view()
                .get_home(GetHomeRequest {
                    budget_minutes: budget,
                })
                .unwrap()
                .template_plans
                .into_iter()
                .find(|p| p.template_id == template.id)
                .unwrap();
            let previewed: Vec<ExerciseDecision> = preview
                .plans
                .into_iter()
                .map(|p| p.decision.unwrap())
                .collect();
            let started = app
                .call()
                .start_workout(StartWorkoutRequest {
                    template_id: template.id.clone(),
                    budget_minutes: budget,
                    ..Default::default()
                })
                .unwrap();
            let recorded: Vec<ExerciseDecision> = started
                .exercise_logs
                .into_iter()
                .map(|l| l.decision.unwrap())
                .collect();
            assert_eq!(previewed, recorded, "budget {budget}");
            assert_eq!(
                preview.estimated_seconds,
                recorded.iter().map(|d| d.estimated_seconds).sum::<i32>()
            );
            app.call()
                .end_workout(EndWorkoutRequest {
                    workout_id: started.id,
                    ended_at: 0,
                })
                .unwrap();
        }
    }

    /// More time, more sets: 2 each at the floor, up to 5; and a budget two
    /// sets each don't fit says how long the workout needs.
    #[test]
    fn the_budget_sets_the_sets() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let lifts = [
            Exercise::LateralRaise,
            Exercise::BarbellCurl,
            Exercise::TricepPushdown,
        ];
        for lift in lifts {
            import_session(&mut app, lift, 30.0, 10, &[10, 10, 10], NOW - 3 * DAY);
        }
        let preview = |app: &App, budget: i32| {
            app.view()
                .get_home(GetHomeRequest {
                    budget_minutes: budget,
                })
                .unwrap()
                .plans
                .into_iter()
                .filter_map(|p| p.decision)
                .filter(|d| lifts.iter().any(|l| *l as i32 == d.exercise))
                .collect::<Vec<_>>()
        };
        assert!(preview(&app, 60).iter().all(|d| d.sets == 5), "alone");
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                exercises: lifts.iter().map(|l| *l as i32).collect(),
                budget_minutes: 25,
                ..Default::default()
            })
            .unwrap();
        let decided: Vec<ExerciseDecision> = started
            .exercise_logs
            .iter()
            .filter_map(|l| l.decision.clone())
            .collect();
        let total: i32 = decided.iter().map(|d| d.estimated_seconds).sum();
        assert!(total <= 25 * 60, "{total}");
        assert!(sets(&decided).iter().all(|n| (2..=5).contains(n)));
        assert!(
            sets(&decided).iter().sum::<i32>() > 6,
            "{:?}",
            sets(&decided)
        );
        assert!(decided.iter().all(|d| d.budget_minutes == 25));
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: started.id,
                ended_at: 0,
            })
            .unwrap();

        let tight = app
            .call()
            .start_workout(StartWorkoutRequest {
                exercises: lifts.iter().map(|l| *l as i32).collect(),
                budget_minutes: 5,
                ..Default::default()
            })
            .unwrap();
        let decided: Vec<ExerciseDecision> = tight
            .exercise_logs
            .iter()
            .filter_map(|l| l.decision.clone())
            .collect();
        assert_eq!(sets(&decided), vec![2, 2, 2], "the floor");
        let needs: i32 = decided.iter().map(|d| d.estimated_seconds).sum();
        assert!(needs > 5 * 60, "needs {} min", needs / 60 + 1);
    }

    /// A lift added mid-workout is planned in the workout's budget around
    /// the lifts already there, which keep theirs.
    #[test]
    fn an_added_lift_fits_around_the_planned_ones() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::BarbellCurl,
            50.0,
            10,
            &[10, 10],
            NOW - 3 * DAY,
        );
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                exercises: vec![Exercise::LateralRaise as i32],
                budget_minutes: 15,
                ..Default::default()
            })
            .unwrap();
        let before = decision(&started, Exercise::LateralRaise);
        app.call()
            .add_exercises(AddExercisesRequest {
                workout_id: started.id.clone(),
                exercises: vec![Exercise::BarbellCurl as i32],
                ..Default::default()
            })
            .unwrap();
        let state = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: started.id.clone(),
            })
            .unwrap();
        let decisions: Vec<ExerciseDecision> = state
            .exercise_logs
            .iter()
            .filter_map(|l| l.decision.clone())
            .collect();
        assert_eq!(decisions[0], before, "the planned lift keeps its decision");
        assert_eq!(decisions[1].budget_minutes, 15);
        assert_eq!(
            working(&state.proposed_sets, Exercise::BarbellCurl).len(),
            decisions[1].sets as usize
        );
        assert_eq!(decisions[1].sets, 2, "15 minutes are spent already");
    }
}

mod recorded {
    use super::*;

    /// Folding a start lays out the decision recorded on it, whatever the
    /// plan would say now: a change to the rules never changes a workout
    /// already started.
    #[test]
    fn a_started_workout_follows_its_recorded_decision() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let recorded = ExerciseDecision {
            exercise: Exercise::Squat as i32,
            sets: 2,
            reps: 7,
            weight: 123.0,
            rest_seconds: 100,
            warmups: false,
            rep_low: 5,
            rep_high: 8,
            max: 170.0,
            budget_minutes: 30,
            ..Default::default()
        };
        assert_ne!(plan(&app, Exercise::Squat), recorded);
        let event = Event {
            seq: app.account.seq + 1,
            id: Uuid::new_v4().to_string(),
            at: NOW,
            kind: Some(event::Kind::StartWorkout(StartWorkoutRequest {
                exercises: vec![Exercise::Squat as i32],
                decisions: vec![recorded.clone()],
                ..Default::default()
            })),
        };
        app.account.apply(&event).unwrap();
        app.account.seq = event.seq;
        app.log.push(event.clone());

        let state = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: event.id.clone(),
            })
            .unwrap();
        let sets: Vec<(f32, i32, i32)> = state
            .proposed_sets
            .iter()
            .map(|s| (s.target_weight, s.target_reps, s.rest_seconds))
            .collect();
        assert_eq!(sets, vec![(123.0, 7, 100); 2]);
        assert_eq!(state.exercise_logs[0].decision, Some(recorded));
    }

    /// A start or an add that names lifts without their decisions (the
    /// shape of a log from before plans were recorded) is refused, not
    /// folded into an empty workout.
    #[test]
    fn a_lift_without_its_decision_is_refused() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let event = |kind| Event {
            seq: 1,
            id: Uuid::new_v4().to_string(),
            at: NOW,
            kind: Some(kind),
        };
        let start = event(event::Kind::StartWorkout(StartWorkoutRequest {
            exercises: vec![Exercise::Squat as i32],
            ..Default::default()
        }));
        assert!(matches!(
            app.account.clone().apply(&start),
            Err(CoreError::InvalidArgument(_))
        ));

        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                exercises: vec![Exercise::Squat as i32],
                ..Default::default()
            })
            .unwrap();
        let add = |exercises: Vec<Exercise>| {
            event(event::Kind::Workout(WorkoutMutation {
                mutation: Some(Mutation::AddExercises(AddExercisesRequest {
                    workout_id: started.id.clone(),
                    exercises: exercises.into_iter().map(|e| e as i32).collect(),
                    ..Default::default()
                })),
                ..Default::default()
            }))
        };
        assert!(matches!(
            app.account.clone().apply(&add(vec![Exercise::BenchPress])),
            Err(CoreError::InvalidArgument(_))
        ));
        // A lift already in the workout keeps its decision: nothing to add.
        assert!(app
            .account
            .clone()
            .apply(&add(vec![Exercise::Squat]))
            .is_ok());
    }
}

mod weight_log {
    use super::*;

    fn at(m: Mutation, t: i64) -> WorkoutMutation {
        WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: t,
            mutation: Some(m),
        }
    }

    fn apply(app: &mut App, m: Mutation) -> GetWorkoutResponse {
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![at(m, 0)],
            })
            .unwrap()
            .workout_state
            .unwrap()
    }

    fn complete(set: &ProposedSet, reps: i32, t: i64) -> Mutation {
        Mutation::CompleteSet(CompleteSetRequest {
            workout_id: set.workout_id.clone(),
            proposed_set_id: set.id.clone(),
            actual_reps: reps,
            actual_weight: set.target_weight,
            completed_at: t,
        })
    }

    fn causes(state: &GetWorkoutResponse) -> Vec<WeightChangeCause> {
        state.exercise_logs[0]
            .changes
            .iter()
            .map(|c| WeightChangeCause::try_from(c.cause).unwrap())
            .collect()
    }

    /// Every cause, through the real calls: the ramp's next rung, its
    /// settling, the user's own change and a fixed set.
    #[test]
    fn every_change_is_logged_with_its_cause() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let rung1 = started.proposed_sets[0].clone();
        assert!(rung1.calibration);
        let state = apply(&mut app, complete(&rung1, 5, NOW + 100));
        assert_eq!(causes(&state), vec![WeightChangeCause::CalibrationStep]);
        let rung2 = state.proposed_sets[1].clone();
        let state = apply(&mut app, complete(&rung2, 3, NOW + 300));
        assert_eq!(
            causes(&state),
            vec![
                WeightChangeCause::CalibrationStep,
                WeightChangeCause::CalibrationSettled
            ]
        );
        let first = working(&state.proposed_sets, Exercise::Squat)[0].clone();
        apply(&mut app, complete(&first, first.target_reps, NOW + 500));
        let state = apply(
            &mut app,
            Mutation::AdjustExerciseWeight(AdjustExerciseWeightRequest {
                workout_id: started.id.clone(),
                exercise: Exercise::Squat as i32,
                working_weight: 40.0,
                target_reps: 0,
            }),
        );
        let done = state
            .completed_sets
            .iter()
            .find(|c| c.proposed_set_id == first.id)
            .unwrap()
            .clone();
        let state = apply(
            &mut app,
            Mutation::EditCompletedSet(EditCompletedSetRequest {
                workout_id: started.id.clone(),
                completed_set_id: done.id.clone(),
                actual_reps: done.actual_reps,
                actual_weight: done.actual_weight - 5.0,
            }),
        );
        assert_eq!(
            causes(&state),
            vec![
                WeightChangeCause::CalibrationStep,
                WeightChangeCause::CalibrationSettled,
                WeightChangeCause::UserAdjust,
                WeightChangeCause::Correction,
            ]
        );
        let changes = &state.exercise_logs[0].changes;
        assert_eq!(changes[2].after, 40.0);
        assert_eq!(changes[2].at, NOW, "the event's time");
        assert_eq!(changes[3].from_set_id, first.id);
    }
}

mod calibration {
    use super::*;

    fn mutation_at(m: Mutation, at: i64) -> WorkoutMutation {
        WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: at,
            mutation: Some(m),
        }
    }

    /// The first-time "I lift X", before any rung: the ramp gives way to
    /// the warmup ladder and the decision's working sets at X.
    #[test]
    fn a_weight_given_up_front_skips_the_ramp() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let d = decision(&started, Exercise::Squat);
        let state = app
            .call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation_at(
                    Mutation::AdjustExerciseWeight(AdjustExerciseWeightRequest {
                        workout_id: started.id.clone(),
                        exercise: Exercise::Squat as i32,
                        working_weight: 135.0,
                        ..Default::default()
                    }),
                    1_050,
                )],
            })
            .unwrap()
            .workout_state
            .unwrap();
        let squat: Vec<&ProposedSet> = state
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32)
            .collect();
        assert!(squat.iter().all(|s| !s.calibration), "no ramp left");
        assert!(squat.iter().any(|s| s.warmup), "a ladder up to it");
        let working: Vec<_> = squat.iter().filter(|s| !s.warmup).collect();
        assert_eq!(working.len(), d.sets as usize);
        assert!(working
            .iter()
            .all(|s| s.target_weight == 135.0 && s.target_reps == d.reps));
    }

    #[test]
    fn bodyweight_never_calibrates() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::PullUp]);
        let d = decision(&started, Exercise::PullUp);
        assert_eq!(started.proposed_sets.len(), d.sets as usize);
        assert!(started.proposed_sets.iter().all(|s| !s.calibration));
        assert_eq!(d.reps, 5, "the bottom of the range");
    }

    /// The whole ramp through the real calls: a full rung climbs, a miss
    /// gives the max and the working sets follow from it, and once ended
    /// the lift's next plan carries on from that max.
    #[test]
    fn the_ramp_finds_a_max_and_the_next_plan_follows() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat, Exercise::Crunch]);
        let rung1 = started.proposed_sets[0].clone();
        assert_eq!(rung1.target_weight, 45.0, "no starting weight: the bar");
        let complete = |set: &ProposedSet, at: i64, reps: i32| {
            mutation_at(
                Mutation::CompleteSet(CompleteSetRequest {
                    workout_id: set.workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: reps,
                    actual_weight: set.target_weight,
                    completed_at: at,
                }),
                at,
            )
        };
        let state = app
            .call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![complete(&rung1, NOW + 100, 5)],
            })
            .unwrap()
            .workout_state
            .unwrap();
        assert_eq!(state.completed_sets[0].rest_until, NOW + 190);
        let rung2 = state.proposed_sets[1].clone();
        assert!(rung2.calibration);
        assert_eq!(rung2.target_weight, 50.0);
        assert_eq!(state.proposed_sets[2].exercise, Exercise::Crunch as i32);

        let state = app
            .call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![complete(&rung2, NOW + 300, 3)],
            })
            .unwrap()
            .workout_state
            .unwrap();
        let squat = working(&state.proposed_sets, Exercise::Squat);
        assert_eq!(
            squat.len(),
            decision(&started, Exercise::Squat).sets as usize
        );
        let mut done: Vec<WorkoutMutation> = squat
            .iter()
            .enumerate()
            .map(|(n, s)| complete(s, NOW + 600 + 200 * n as i64, s.target_reps))
            .collect();
        done.push(mutation_at(
            Mutation::EndWorkout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: NOW + 2_500,
            }),
            NOW + 2_500,
        ));
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest { mutations: done })
            .unwrap();

        app.now = NOW + DAY;
        let next = plan(&app, Exercise::Squat);
        assert!(!next.calibration, "found: no more ramps");
        assert_eq!(kinds(&next)[0], PlanReasonKind::MaxUp);
        assert!(
            next.max > 50.0 * (1.0 + 3.0 / 30.0),
            "above what the rung showed"
        );
        let shown = app.view().exercise_plan(Exercise::Squat, 0);
        assert_eq!(shown.last_performed_at, NOW + 2_500);
    }
}

mod batches {
    use super::*;

    fn mutation(m: Mutation) -> WorkoutMutation {
        WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: 0,
            mutation: Some(m),
        }
    }

    /// Removing a lift mid-session is stopping early: the max holds.
    #[test]
    fn removing_an_exercise_mid_session_holds_the_max() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::LateralRaise,
            20.0,
            10,
            &[10, 10, 10],
            NOW - DAY,
        );
        let before = plan(&app, Exercise::LateralRaise);
        let started = start(&mut app, &[Exercise::LateralRaise]);
        let first = working(&started.proposed_sets, Exercise::LateralRaise)[0].clone();
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![
                    mutation(Mutation::CompleteSet(CompleteSetRequest {
                        workout_id: started.id.clone(),
                        proposed_set_id: first.id.clone(),
                        actual_reps: first.target_reps,
                        actual_weight: first.target_weight,
                        completed_at: NOW + 100,
                    })),
                    mutation(Mutation::RemoveExercise(RemoveExerciseRequest {
                        workout_id: started.id.clone(),
                        exercise: Exercise::LateralRaise as i32,
                    })),
                ],
            })
            .unwrap();
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(Mutation::EndWorkout(EndWorkoutRequest {
                    workout_id: started.id.clone(),
                    ended_at: NOW + 200,
                }))],
            })
            .unwrap();
        let after = plan(&app, Exercise::LateralRaise);
        assert_eq!(kinds(&after)[0], PlanReasonKind::Held);
        assert_eq!(after.max, before.max);
    }

    /// A mutation that can never apply must be consumed, not retried: one
    /// poison mutation would otherwise wedge every completion queued
    /// behind it, permanently.
    #[test]
    fn a_poison_mutation_is_skipped_and_the_rest_of_the_batch_applies() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::LateralRaise]);
        let first_set = started.proposed_sets[0].id.clone();

        let response = app
            .call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![
                    // Rejected by the weight range check.
                    mutation(Mutation::AdjustExerciseWeight(
                        AdjustExerciseWeightRequest {
                            workout_id: started.id.clone(),
                            exercise: Exercise::LateralRaise as i32,
                            working_weight: -50.0,
                            target_reps: 0,
                        },
                    )),
                    mutation(Mutation::CompleteSet(CompleteSetRequest {
                        workout_id: started.id.clone(),
                        proposed_set_id: first_set.clone(),
                        actual_reps: 10,
                        actual_weight: 20.0,
                        completed_at: 1_100,
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
        assert_eq!(state.completed_sets.len(), 1);
        assert!(state.proposed_sets.iter().all(|s| s.target_weight >= 0.0));
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
                ..Default::default()
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
    /// that strength records.
    #[test]
    fn the_slider_shows_what_onboarding_records() {
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
            app.call()
                .complete_onboarding(CompleteOnboardingRequest {
                    unit: unit as i32,
                    strength: Some(step as f32 / 100.0),
                    ..Default::default()
                })
                .unwrap();
            for w in &shown[step].weights {
                assert_eq!(
                    app.account.starting_weights.get(&w.exercise),
                    Some(&w.weight_lb),
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

mod rotation {
    use super::*;

    fn by_library(home: &GetHomeResponse, id: &str) -> WorkoutTemplate {
        home.templates
            .iter()
            .find(|t| t.library_id == id)
            .cloned()
            .unwrap()
    }

    /// The workouts picked at onboarding are the rotation; a library
    /// template added later and one the user makes are favourites unless
    /// saved otherwise.
    #[test]
    fn onboarding_fills_the_rotation_and_later_ones_are_favourites() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        assert!(onboarded.templates.iter().all(|t| t.in_rotation));
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["full_body".into()],
                entries: vec![],
            })
            .unwrap();
        let mine = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(WorkoutTemplate {
                    name: "Mine".into(),
                    exercises: vec![Exercise::BarbellCurl as i32],
                    ..Default::default()
                }),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        let after = home(&mut app);
        assert!(!by_library(&after, "full_body").in_rotation);
        assert!(!mine.in_rotation);
        assert!(by_library(&after, "stronglifts_a").in_rotation);
        assert!(after.rotation_check.is_some());
    }

    /// Putting a library template in rotation (or out) keeps it following
    /// the library, even after the library has changed it.
    #[test]
    fn rotation_is_saved_without_unlinking() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["full_body".into()],
                entries: vec![],
            })
            .unwrap();
        app.library
            .iter_mut()
            .find(|e| e.id == "full_body")
            .unwrap()
            .name = "Full Body+".into();
        let mut shown = by_library(&home(&mut app), "full_body");
        assert_eq!(shown.name, "Full Body+");
        shown.in_rotation = true;
        let saved = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(shown.clone()),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        assert!(saved.coupled && saved.in_rotation, "{saved:?}");
        let after = by_library(&home(&mut app), "full_body");
        assert_eq!(after.name, "Full Body+", "still follows the library");
        assert!(after.in_rotation);

        // Saving it unchanged again records nothing.
        let events = app.log.len();
        app.call()
            .save_template(SaveTemplateRequest {
                template: Some(after),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(app.log.len(), events);
    }

    /// A favourite is never suggested, however far behind its muscles are.
    #[test]
    fn the_suggestion_comes_from_the_rotation() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["arms".into()],
                entries: vec![],
            })
            .unwrap();
        let after = home(&mut app);
        let rotation: Vec<&str> = onboarded.templates.iter().map(|t| t.id.as_str()).collect();
        assert!(rotation.contains(&after.suggested_template_id.as_str()));
    }
}
