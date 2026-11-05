//! The account's API end to end, as the app uses it: onboarding → home →
//! start → sets done → end → the next plan follows. Every test also checks
//! that replaying the recorded events rebuilds exactly the same account.

use schlift_core::account::{Account, CoreError};
use schlift_core::api::{Call, View};
use schlift_core::events::{Event, ExercisesAdded, Fact, WorkoutStarted};
use schlift_core::pb::workout_mutation::Mutation;
use schlift_core::pb::*;
use uuid::Uuid;

/// One change to a workout, as the app sends it.
fn mutation(m: Mutation) -> WorkoutMutation {
    WorkoutMutation { mutation: Some(m) }
}

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
        assert_eq!(Account::fold(&self.log), self.account, "replay rebuilds it");
        // The server's fold is the same, less every heart-rate reading.
        let mut server = self.account.clone();
        server.without_heart_rate = true;
        for record in &mut server.workouts {
            record.heart_rate.clear();
        }
        assert_eq!(
            Account::fold_without_heart_rate(&self.log),
            server,
            "the server's fold is the phone's without heart rate"
        );
    }
}

fn onboard(app: &mut App, unit: WeightUnit) -> GetHomeResponse {
    app.call()
        .complete_onboarding(CompleteOnboardingRequest {
            unit: unit as i32,
            ..Default::default()
        })
        .unwrap();
    app.view().home(0)
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
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(Mutation::CompleteSet(CompleteSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: reps_for(set),
                    actual_weight: set.target_weight,
                    completed_at: ts,
                }))],
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
        app.call()
            .complete_onboarding(CompleteOnboardingRequest {
                unit: WeightUnit::Lb as i32,
                library_ids: vec!["stronglifts_a".into(), "butt_stuff".into()],
                ..Default::default()
            })
            .unwrap();
        let home = app.view().home(0);
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
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["butt_stuff".into(), already.clone()],
                ..Default::default()
            })
            .unwrap();
        let home = app.view().home(0);
        assert_eq!(home.templates.len(), before + 1);
        let added = home.templates.last().unwrap();
        assert_eq!(added.library_id, "butt_stuff");
        assert_eq!(added.name, "Butt Stuff");

        assert!(added.coupled, "a library workout follows the library");

        // Saved unchanged it still follows; renamed it becomes the user's
        // own, made from the entry, and the entry is not added again
        // beside it.
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
        assert_eq!(renamed.origin_library_id, "butt_stuff");
        let events = app.log.len();
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["butt_stuff".into()],
                ..Default::default()
            })
            .unwrap();
        let home = app.view().home(0);
        assert_eq!(home.templates.len(), before + 1, "no duplicate");
        assert_eq!(app.log.len(), events, "nothing to record");

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
        let Fact::Onboarded(recorded) = &app.log[0].fact else {
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
                ..Default::default()
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

    /// Ending a workout offers its lifts as a template when they are not
    /// its template's: here only the squat of two was done. Done as
    /// planned, or with nothing done, there is no offer; started from no
    /// template, the offer is a new one.
    #[test]
    fn ending_offers_the_lifts_done_when_they_differ() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let legs = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(template("Legs", &[Exercise::Squat, Exercise::CalfRaise])),
                ..Default::default()
            })
            .unwrap()
            .template
            .unwrap();
        let end = |app: &mut App, template_id: &str, done: &[Exercise]| {
            let started = app
                .call()
                .start_workout(StartWorkoutRequest {
                    template_id: template_id.to_string(),
                    exercises: if template_id.is_empty() {
                        vec![Exercise::Squat as i32]
                    } else {
                        vec![]
                    },
                    ..Default::default()
                })
                .unwrap();
            let now = app.now;
            for exercise in done {
                let set = started
                    .proposed_sets
                    .iter()
                    .find(|s| s.exercise == *exercise as i32 && !s.warmup)
                    .unwrap()
                    .clone();
                app.call()
                    .append_workout_mutations(AppendWorkoutMutationsRequest {
                        mutations: vec![mutation(Mutation::CompleteSet(CompleteSetRequest {
                            workout_id: started.id.clone(),
                            proposed_set_id: set.id,
                            actual_reps: set.target_reps,
                            actual_weight: set.target_weight,
                            completed_at: now,
                        }))],
                    })
                    .unwrap();
            }
            app.call()
                .end_workout(EndWorkoutRequest {
                    workout_id: started.id,
                    ended_at: now + 60,
                })
                .unwrap()
                .template_offer
        };

        let offer = end(&mut app, &legs.id, &[Exercise::Squat]).expect("an offer");
        assert_eq!(offer.template_id, legs.id);
        assert_eq!(offer.template_name, "Legs");
        assert_eq!(offer.exercises, vec![Exercise::Squat as i32]);

        let both = [Exercise::CalfRaise, Exercise::Squat];
        assert_eq!(end(&mut app, &legs.id, &both), None);
        assert_eq!(end(&mut app, &legs.id, &[]), None);

        let offer = end(&mut app, "", &[Exercise::Squat]).expect("an offer");
        assert_eq!(offer.template_id, "");
        assert_eq!(offer.exercises, vec![Exercise::Squat as i32]);
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
        assert_eq!(kinds(&squat)[1], PlanReasonKind::MaxUp);
        // Five sets in the hour against last time's three: the rep the hit
        // earned goes to the extra sets, and the first reason says so.
        assert_eq!(squat.sets, 5);
        assert_eq!(kinds(&squat)[0], PlanReasonKind::SameAsLast);
        assert_eq!(squat.reasons[0].cause, PlanChangeCause::Sets as i32);
        assert_eq!(
            (squat.reasons[0].sets_before, squat.reasons[0].sets_after),
            (3, 5)
        );

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
        assert_eq!(kinds(&after)[1], PlanReasonKind::MaxFromMiss);
        assert!(after.max < before);
        assert!(after.reps < 7 || after.weight < 200.0);
    }

    /// Each plan carries the lift's step: the plate pair for a barbell, the
    /// dumbbell rack's step, none for bodyweight.
    #[test]
    fn a_plan_carries_its_lifts_step() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Kg);
        let step = |exercise| app.view().exercise_plan(exercise, 0).step;
        let kg = |lb: f32| (schlift_core::weight_units::pounds_to_kg(lb) * 100.0).round() / 100.0;
        assert_eq!(kg(step(Exercise::Squat)), 2.5);
        assert_eq!(kg(step(Exercise::DumbbellRow)), 2.0);
        assert_eq!(step(Exercise::PullUp), 0.0);
    }

    /// A finished workout's summary carries each lift's estimated max
    /// after it: the progress point's.
    #[test]
    fn the_summary_carries_the_max_after_the_session() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(&mut app, Exercise::Squat, 200.0, 6, &[6, 6, 6], NOW - DAY);
        let started = start(&mut app, &[Exercise::Squat]);
        finish(&mut app, &started, |s| s.target_reps, NOW + 60);
        let point = app.view().get_exercise_progress().exercises[0]
            .points
            .iter()
            .find(|p| p.workout_id == started.id)
            .unwrap()
            .estimated_max;
        let summary = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: started.id.clone(),
            })
            .unwrap()
            .summary
            .unwrap();
        assert!(point > 0.0);
        assert_eq!(summary.exercises[0].estimated_max_after, point);
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
            app.view().list_workout_summaries().workouts[0]
                .workout
                .as_ref()
                .unwrap()
                .end_time,
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
        assert_eq!(kinds(&next)[0], PlanReasonKind::RepsUp);
        assert_eq!(next.reasons[0].cause, PlanChangeCause::Hit as i32);
        assert_eq!(kinds(&next)[1], PlanReasonKind::MaxUp);

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
                PlanReasonKind::WeightDown,
                PlanReasonKind::MaxUp,
                PlanReasonKind::TimeOff,
                PlanReasonKind::SetsFromTime
            ]
        );
        assert_eq!(d.reasons[0].cause, PlanChangeCause::TimeOff as i32);
        assert_eq!(d.reasons[2].days_off, 45);
        assert!((d.max - d.reasons[2].before * 0.8).abs() < 1e-3);
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
            // The template editor's plan of the same lifts is Home's.
            let edited = app
                .view()
                .get_template_plan(GetTemplatePlanRequest {
                    exercises: template.exercises.clone(),
                    budget_minutes: budget,
                })
                .unwrap()
                .plan
                .unwrap();
            assert_eq!(edited.plans, preview.plans, "budget {budget}");
            assert_eq!(edited.estimated_seconds, preview.estimated_seconds);
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

    /// The longest a workout gets: every free lift at five sets, an
    /// override's sets as they are. A budget past it plans exactly that.
    #[test]
    fn the_longest_a_workout_gets() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let lifts = [Exercise::Squat, Exercise::BenchPress, Exercise::BarbellRow];
        for lift in lifts {
            import_session(&mut app, lift, 100.0, 5, &[5, 5, 5], NOW - 3 * DAY);
        }
        app.call()
            .set_override(SetOverrideRequest {
                exercise: Exercise::BenchPress as i32,
                weight: 100.0,
                reps: 5,
                sets: Some(2),
            })
            .unwrap();
        let plan = |budget: i32| {
            app.view()
                .get_template_plan(GetTemplatePlanRequest {
                    exercises: lifts.iter().map(|l| *l as i32).collect(),
                    budget_minutes: budget,
                })
                .unwrap()
                .plan
                .unwrap()
        };
        let roomy = plan(600);
        let decided: Vec<ExerciseDecision> = roomy
            .plans
            .iter()
            .filter_map(|p| p.decision.clone())
            .collect();
        assert_eq!(sets(&decided), vec![5, 2, 5], "the override's sets kept");
        assert_eq!(roomy.estimated_seconds, roomy.max_seconds);
        let tight = plan(20);
        assert_eq!(tight.max_seconds, roomy.max_seconds, "the budget's own");
        assert!(tight.estimated_seconds < tight.max_seconds);
        // The cap is a budget that plans it all.
        let cap = plan((roomy.max_seconds + 59) / 60);
        assert_eq!(cap.estimated_seconds, cap.max_seconds);
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
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(Mutation::AddExercises(AddExercisesRequest {
                    workout_id: started.id.clone(),
                    exercises: vec![Exercise::BarbellCurl as i32],
                    ..Default::default()
                }))],
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
            seq: 0,
            id: Uuid::new_v4().to_string(),
            at: NOW,
            fact: Fact::WorkoutStarted(WorkoutStarted {
                started_at: NOW,
                exercises: vec![Exercise::Squat as i32],
                decisions: vec![recorded.clone()],
                ..Default::default()
            }),
        };
        app.account.apply(&event).unwrap();
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

    /// A start or an add that names lifts without their decisions is
    /// refused, not folded into an empty workout.
    #[test]
    fn a_lift_without_its_decision_is_refused() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let event = |fact| Event {
            seq: 0,
            id: Uuid::new_v4().to_string(),
            at: NOW,
            fact,
        };
        let start = event(Fact::WorkoutStarted(WorkoutStarted {
            started_at: NOW,
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
            event(Fact::ExercisesAdded(ExercisesAdded {
                workout_id: started.id.clone(),
                exercises: exercises.into_iter().map(|e| e as i32).collect(),
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

    fn apply(app: &mut App, m: Mutation) -> GetWorkoutResponse {
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(m)],
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

    /// Fewer reps on a ramp set never plan heavier, whatever was answered
    /// before it: a set short of its reps caps the max an answer implied.
    #[test]
    fn fewer_reps_on_a_rung_never_plan_heavier() {
        let answers = [
            (RepsLeft::Unspecified, 0.0),
            (RepsLeft::TwoToFour, 0.0),
            (RepsLeft::FivePlus, 0.0),
            (RepsLeft::Unspecified, 40.0),
        ];
        for (reps_left, jump_lb) in answers {
            let mut app = App::new();
            onboard(&mut app, WeightUnit::Lb);
            let started = start(&mut app, &[Exercise::Squat]);
            let rung1 = started.proposed_sets[0].clone();
            let state = apply(&mut app, complete(&rung1, 5, NOW + 100));
            if reps_left != RepsLeft::Unspecified || jump_lb > 0.0 {
                apply(
                    &mut app,
                    Mutation::AnswerRung(AnswerRungRequest {
                        workout_id: started.id.clone(),
                        proposed_set_id: rung1.id.clone(),
                        reps_left: reps_left as i32,
                        jump_lb,
                    }),
                );
            }
            let state = app.view().workout_response(&started.id).unwrap_or(state);
            let rung2 = state
                .proposed_sets
                .iter()
                .find(|s| s.calibration && s.id != rung1.id)
                .unwrap()
                .clone();
            let state = apply(&mut app, complete(&rung2, 5, NOW + 300));
            let done = state
                .completed_sets
                .iter()
                .find(|c| c.proposed_set_id == rung2.id)
                .unwrap()
                .clone();
            let mut last = f32::INFINITY;
            for reps in (0..5).rev() {
                let state = apply(
                    &mut app,
                    Mutation::EditCompletedSet(EditCompletedSetRequest {
                        workout_id: started.id.clone(),
                        completed_set_id: done.id.clone(),
                        actual_reps: reps,
                        actual_weight: done.actual_weight,
                    }),
                );
                let done_ids: Vec<&str> = state
                    .completed_sets
                    .iter()
                    .map(|c| c.proposed_set_id.as_str())
                    .collect();
                let next = state
                    .proposed_sets
                    .iter()
                    .find(|s| {
                        s.exercise == Exercise::Squat as i32
                            && !s.warmup
                            && !done_ids.contains(&s.id.as_str())
                    })
                    .unwrap()
                    .target_weight;
                assert!(
                    next <= last,
                    "{reps_left:?} +{jump_lb}: {reps} reps plans {next}, more than {last}"
                );
                last = next;
            }
        }
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

    /// The app adds a lift through the batch, as the watch's intents come:
    /// it is planned there and lands in the workout with its decision.
    #[test]
    fn a_lift_added_through_the_batch_is_planned() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let workout_id = started.workout.unwrap().id;
        let state = apply(
            &mut app,
            Mutation::AddExercises(AddExercisesRequest {
                workout_id,
                exercises: vec![Exercise::BarbellCurl as i32],
                ..Default::default()
            }),
        );
        assert!(state
            .proposed_sets
            .iter()
            .any(|s| s.exercise == Exercise::BarbellCurl as i32));
        assert!(state
            .exercise_logs
            .iter()
            .any(|l| l.decision.as_ref().unwrap().exercise == Exercise::BarbellCurl as i32));
    }
}

mod calibration {
    use super::*;

    /// A weight given before the ramp starts ("test me from X"): the
    /// ramp's first set moves to X and the ramp goes on from there.
    #[test]
    fn a_weight_given_up_front_starts_the_ramp_there() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let state = app
            .call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(Mutation::AdjustExerciseWeight(
                    AdjustExerciseWeightRequest {
                        workout_id: started.id.clone(),
                        exercise: Exercise::Squat as i32,
                        working_weight: 135.0,
                        ..Default::default()
                    },
                ))],
            })
            .unwrap()
            .workout_state
            .unwrap();
        let squat: Vec<&ProposedSet> = state
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32 && !s.cancelled)
            .collect();
        assert_eq!(squat.len(), 1, "still the one rung");
        assert!(squat[0].calibration, "still ramping");
        assert_eq!(squat[0].target_weight, 135.0);
    }

    /// A never-done lift's ramp asks for a weight until it is started or
    /// a rung of it is done; a lift with no ramp never asks.
    #[test]
    fn a_ramp_asks_for_a_weight_until_it_is_started() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat, Exercise::PullUp]);
        let rung1 = started.proposed_sets[0].clone();
        let batch = |app: &mut App, m: Mutation| {
            app.call()
                .append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![mutation(m)],
                })
                .unwrap()
                .workout_state
                .unwrap()
        };
        let state = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: started.id.clone(),
            })
            .unwrap();
        assert_eq!(state.first_time_set_ids, vec![rung1.id.clone()]);
        let state = batch(
            &mut app,
            Mutation::StartSet(StartSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: rung1.id.clone(),
                started_at: NOW + 10,
            }),
        );
        assert!(state.first_time_set_ids.is_empty(), "started: tested");
        let state = batch(
            &mut app,
            Mutation::CompleteSet(CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: rung1.id.clone(),
                actual_reps: 5,
                actual_weight: rung1.target_weight,
                completed_at: NOW + 60,
            }),
        );
        assert!(state.first_time_set_ids.is_empty(), "a rung done");
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
            mutation(Mutation::CompleteSet(CompleteSetRequest {
                workout_id: set.workout_id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps,
                actual_weight: set.target_weight,
                completed_at: at,
            }))
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
        done.push(mutation(Mutation::EndWorkout(EndWorkoutRequest {
            workout_id: started.id.clone(),
            ended_at: NOW + 2_500,
        })));
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest { mutations: done })
            .unwrap();

        app.now = NOW + DAY;
        let next = plan(&app, Exercise::Squat);
        assert!(!next.calibration, "found: no more ramps");
        assert!(kinds(&next).contains(&PlanReasonKind::MaxUp));
        assert!(
            next.max > 50.0 * (1.0 + 3.0 / 30.0),
            "above what the rung showed"
        );
        let shown = app.view().exercise_plan(Exercise::Squat, 0);
        assert_eq!(shown.last_performed_at, NOW + 2_500);
    }

    /// The ramp's question through the batch, as the phone and the watch
    /// send it: answered 0–1 the ramp ends there, the working sets follow
    /// from the max with the answer's reserve, an answer to it again is
    /// ignored, and the walk afterwards reads the same max. The replay
    /// (App's drop) rebuilds it all.
    #[test]
    fn an_answer_settles_the_ramp_and_the_walk_reads_it() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let rung1 = started.proposed_sets[0].clone();
        let batch = |app: &mut App, m: Mutation| {
            app.call()
                .append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![mutation(m)],
                })
                .unwrap()
                .workout_state
                .unwrap()
        };
        let done = |set: &ProposedSet, reps: i32| {
            Mutation::CompleteSet(CompleteSetRequest {
                workout_id: set.workout_id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps,
                actual_weight: set.target_weight,
                completed_at: 0,
            })
        };
        let answer = |set: &ProposedSet, reps_left: RepsLeft| {
            Mutation::AnswerRung(AnswerRungRequest {
                workout_id: set.workout_id.clone(),
                proposed_set_id: set.id.clone(),
                reps_left: reps_left as i32,
                jump_lb: 0.0,
            })
        };
        let state = batch(&mut app, done(&rung1, 5));
        assert_eq!(state.rung_question_set_id, rung1.id);
        // What each answer leads to, offered with the question: 0–1 the
        // working sets, the others a next rung; 5+ is kept to the pound.
        let outcome = |reps_left: RepsLeft| {
            state
                .rung_outcomes
                .iter()
                .find(|o| o.reps_left == reps_left as i32)
                .cloned()
                .unwrap()
        };
        assert_eq!(state.rung_outcomes.len(), 3);
        assert!(outcome(RepsLeft::ZeroToOne).settles);
        assert!(!outcome(RepsLeft::TwoToFour).settles);
        let promised = outcome(RepsLeft::FivePlus);
        assert!(!promised.settles);
        let rung2 = state.proposed_sets[1].clone();
        let state = batch(&mut app, answer(&rung1, RepsLeft::FivePlus));
        assert!(state.rung_outcomes.is_empty(), "the question is closed");
        assert_eq!(state.proposed_sets[1].target_weight, promised.weight);
        assert!(state.rung_question_set_id.is_empty());
        assert_eq!(
            state.proposed_sets[1].id, rung2.id,
            "the next rung keeps its id"
        );
        let state = batch(&mut app, done(&rung2, 5));
        assert_eq!(state.rung_question_set_id, rung2.id);
        let state = batch(&mut app, answer(&rung2, RepsLeft::ZeroToOne));
        let squat = working(&state.proposed_sets, Exercise::Squat);
        assert_eq!(
            squat.len(),
            decision(&started, Exercise::Squat).sets as usize
        );
        let stale = batch(&mut app, answer(&rung2, RepsLeft::FivePlus));
        assert_eq!(
            working(&stale.proposed_sets, Exercise::Squat),
            squat,
            "answered: ignored"
        );
        batch(
            &mut app,
            Mutation::EndWorkout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: NOW + 400,
            }),
        );

        // Ended before the working sets: the max holds at what the ramp
        // found, rung 2 with half a rep in reserve.
        let ramp_max = rung2.target_weight * (1.0 + 5.5 / 30.0);
        app.now = NOW + DAY;
        let next = plan(&app, Exercise::Squat);
        assert!(!next.calibration);
        assert!(
            (next.max - ramp_max).abs() < 1e-3,
            "{} vs {ramp_max}",
            next.max
        );
    }

    /// Started far too heavy ("test me from X" past the lifter's max): a
    /// rung of 0 reps steps the ramp down a fifth with no question, a 3-rep
    /// rung there settles it, and the walk's max is that rung's, never the
    /// too-heavy one's. The log says it stepped down. The replay (App's
    /// drop) rebuilds it.
    #[test]
    fn an_overshot_ramp_steps_down_and_the_walk_ignores_the_heavy_rung() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let batch = |app: &mut App, m: Mutation| {
            app.call()
                .append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![mutation(m)],
                })
                .unwrap()
                .workout_state
                .unwrap()
        };
        let done = |set: &ProposedSet, reps: i32| {
            Mutation::CompleteSet(CompleteSetRequest {
                workout_id: set.workout_id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps,
                actual_weight: set.target_weight,
                completed_at: 0,
            })
        };
        let state = batch(
            &mut app,
            Mutation::AdjustExerciseWeight(AdjustExerciseWeightRequest {
                workout_id: started.id.clone(),
                exercise: Exercise::Squat as i32,
                working_weight: 200.0,
                ..Default::default()
            }),
        );
        let rung1 = state.proposed_sets[0].clone();
        assert_eq!(rung1.target_weight, 200.0);
        let state = batch(&mut app, done(&rung1, 0));
        assert!(state.rung_question_set_id.is_empty(), "a miss: no question");
        let rung2 = state.proposed_sets[1].clone();
        assert!(rung2.calibration, "the ramp goes on");
        assert_eq!(rung2.target_weight, 160.0, "a fifth lighter");
        let state = batch(&mut app, done(&rung2, 3));
        let squat = working(&state.proposed_sets, Exercise::Squat);
        assert_eq!(
            squat.len(),
            decision(&started, Exercise::Squat).sets as usize
        );
        let changes: Vec<(i32, f32, f32)> = state
            .exercise_logs
            .iter()
            .flat_map(|l| l.changes.iter())
            .filter(|c| c.cause != WeightChangeCause::UserAdjust as i32)
            .map(|c| (c.cause, c.before, c.after))
            .collect();
        assert_eq!(
            changes[0],
            (WeightChangeCause::CalibrationStep as i32, 200.0, 160.0),
            "a step down: after under before"
        );
        batch(
            &mut app,
            Mutation::EndWorkout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: NOW + 400,
            }),
        );
        let ramp_max = 160.0 * (1.0 + 3.0 / 30.0);
        app.now = NOW + DAY;
        let next = plan(&app, Exercise::Squat);
        assert!(!next.calibration);
        assert!(
            (next.max - ramp_max).abs() < 1e-3,
            "{} vs {ramp_max}",
            next.max
        );
    }

    /// A specific jump through the batch: the next rung is the rung plus
    /// it, the ramp goes on, a second answer is ignored, and the walk
    /// counts the jumped rung's max with the usual rep in reserve. The
    /// replay (App's drop) rebuilds it.
    #[test]
    fn a_jump_climbs_the_ramp_and_the_walk_reads_it() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let rung1 = started.proposed_sets[0].clone();
        let batch = |app: &mut App, m: Mutation| {
            app.call()
                .append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![mutation(m)],
                })
                .unwrap()
                .workout_state
                .unwrap()
        };
        let jump = |set: &ProposedSet, reps_left: RepsLeft, jump_lb: f32| {
            Mutation::AnswerRung(AnswerRungRequest {
                workout_id: set.workout_id.clone(),
                proposed_set_id: set.id.clone(),
                reps_left: reps_left as i32,
                jump_lb,
            })
        };
        let state = batch(
            &mut app,
            Mutation::CompleteSet(CompleteSetRequest {
                workout_id: rung1.workout_id.clone(),
                proposed_set_id: rung1.id.clone(),
                actual_reps: rung1.target_reps,
                actual_weight: rung1.target_weight,
                completed_at: 0,
            }),
        );
        assert_eq!(state.rung_question_set_id, rung1.id);
        let both = batch(&mut app, jump(&rung1, RepsLeft::FivePlus, 50.0));
        assert_eq!(both.rung_question_set_id, rung1.id, "both: ignored");
        let state = batch(&mut app, jump(&rung1, RepsLeft::Unspecified, 50.0));
        assert!(state.rung_question_set_id.is_empty());
        let rung2 = &state.proposed_sets[1];
        assert!(rung2.calibration, "the ramp goes on");
        assert_eq!(rung2.target_weight, rung1.target_weight + 50.0);
        let stale = batch(&mut app, jump(&rung1, RepsLeft::Unspecified, 20.0));
        assert_eq!(
            stale.proposed_sets, state.proposed_sets,
            "answered: ignored"
        );
        batch(
            &mut app,
            Mutation::EndWorkout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: NOW + 400,
            }),
        );

        // Ended after the jumped rung: its max, one rep in reserve.
        let ramp_max = rung1.target_weight * (1.0 + 6.0 / 30.0);
        app.now = NOW + DAY;
        let next = plan(&app, Exercise::Squat);
        assert!(
            (next.max - ramp_max).abs() < 1e-3,
            "{} vs {ramp_max}",
            next.max
        );
    }
}

mod batches {
    use super::*;

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
        assert_eq!(kinds(&after)[1], PlanReasonKind::Held);
        assert_eq!(after.reasons[0].cause, PlanChangeCause::StoppedEarly as i32);
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

        let state = response.workout_state.unwrap();
        assert_eq!(state.completed_sets.len(), 1);
        assert!(state.proposed_sets.iter().all(|s| s.target_weight >= 0.0));
    }
}

mod lifting {
    use super::*;

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
                mutations: vec![mutation(workout_mutation::Mutation::StartSet(
                    StartSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: set.id.clone(),
                        started_at: 1_100,
                    },
                ))],
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
                mutations: vec![mutation(workout_mutation::Mutation::CompleteSet(
                    CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: set.id.clone(),
                        actual_reps: set.target_reps,
                        actual_weight: set.target_weight,
                        completed_at: 1_140,
                    },
                ))],
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

    /// The heart rate gathered so far stays with the workout through the
    /// set changes after it, and through one that is refused.
    #[test]
    fn heart_rate_stays_through_set_changes() {
        let mut app = App::new();
        let started = start(&mut app, &[Exercise::Squat]);
        let start_ms = started.workout.as_ref().unwrap().start_time * 1000;
        let samples: Vec<WorkoutHeartRatePoint> = (0..3)
            .map(|i| WorkoutHeartRatePoint {
                sampled_at: start_ms + 1_000 + i,
                bpm: 120.0,
            })
            .collect();
        app.call().record_heart_rate(&started.id, &samples).unwrap();
        // A set that does not exist: the change is dropped.
        app.call()
            .append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![mutation(Mutation::CompleteSet(CompleteSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: "no such set".into(),
                    actual_reps: 5,
                    ..Default::default()
                }))],
            })
            .unwrap();
        finish(&mut app, &started, |s| s.target_reps, NOW);
        let kept = app
            .view()
            .get_workout_heart_rate(GetWorkoutHeartRateRequest {
                workout_id: started.id.clone(),
            })
            .unwrap()
            .samples;
        assert_eq!(kept, samples);
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
                ..Default::default()
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
        let finished = app.view().list_workout_summaries().workouts;
        assert_eq!(finished.len(), 1);
        assert_eq!(
            finished[0].workout.as_ref().unwrap().end_time,
            NOW,
            "ended at the event's time"
        );
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

    /// Clone in the app opens the editor and records nothing until Save:
    /// the save, unchanged, with `unlink`, makes it the user's own in place:
    /// same id (its history stays with it), the library's exercises of the
    /// moment, and library changes no longer reach it.
    #[test]
    fn an_unchanged_save_with_unlink_makes_it_their_own() {
        let mut app = App::new();
        let template = stronglifts_a(&mut app);
        let cloned = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(template.clone()),
                unlink: true,
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
    /// template added later and one the user makes are reserves unless
    /// saved otherwise.
    #[test]
    fn onboarding_fills_the_rotation_and_later_ones_are_reserves() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        assert!(onboarded.templates.iter().all(|t| t.in_rotation));
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["full_body".into()],
                ..Default::default()
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

    /// The rotation and the reserves, by name, in order.
    fn sections(home: &GetHomeResponse) -> (Vec<String>, Vec<String>) {
        let names = |in_rotation: bool| {
            home.templates
                .iter()
                .filter(|t| t.in_rotation == in_rotation)
                .map(|t| t.name.clone())
                .collect()
        };
        (names(true), names(false))
    }

    fn apply_plan(app: &mut App, plan_id: &str) -> GetHomeResponse {
        app.call()
            .apply_library_plan(ApplyLibraryPlanRequest {
                plan_id: plan_id.into(),
            })
            .unwrap();
        app.view().home(0)
    }

    /// The library lists the ready-made plans built in.
    #[test]
    fn library_lists_the_plans() {
        let app = App::new();
        let listed = app.view().list_template_library().plans;
        assert_eq!(listed, schlift_core::template_library::plans());
        assert!(listed.iter().any(|p| p.id == "push_pull_legs"));
    }

    /// A ready-made plan becomes the rotation in its order: the entries
    /// the user lacks are added, the old rotation moves to the reserves
    /// (nothing is deleted), and the user's own copy of an entry is used
    /// rather than a second one. The replay (App's drop) rebuilds it all.
    #[test]
    fn applying_a_plan_makes_it_the_main_plan() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["arms".into()],
                ..Default::default()
            })
            .unwrap();
        // Pull, made the user's own: it stands for the entry.
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["pull".into()],
                ..Default::default()
            })
            .unwrap();
        let mut pull = by_library(&home(&mut app), "pull");
        pull.name = "My Pull".into();
        app.call()
            .save_template(SaveTemplateRequest {
                template: Some(pull.clone()),
                ..Default::default()
            })
            .unwrap();
        let before = home(&mut app).templates.len();

        let home = apply_plan(&mut app, "push_pull_legs");
        assert_eq!(
            sections(&home),
            (
                vec!["Push".into(), "My Pull".into(), "Legs".into()],
                vec![
                    "StrongLifts A".into(),
                    "StrongLifts B".into(),
                    "Arms".into()
                ],
            ),
        );
        assert_eq!(home.templates.len(), before + 2, "push and legs added");
        assert_eq!(home.current_plan_id, "push_pull_legs");
        for had in ["push", "pull", "legs", "arms"] {
            assert!(
                !home.addable_library_ids.iter().any(|id| id == had),
                "{had} is not offered again"
            );
        }
        assert!(!home.addable_library_ids.is_empty());
        let mine = home.templates.iter().find(|t| t.id == pull.id).unwrap();
        assert!(mine.in_rotation && !mine.coupled, "the user's own is used");
        assert!(
            home.templates
                .iter()
                .filter(|t| t.name == "Push" || t.name == "Legs")
                .all(|t| t.coupled),
            "added ones follow the library"
        );

        // Back to StrongLifts: nothing added, the user's A and B go first
        // and PPL moves to the reserves ahead of Arms.
        let count = home.templates.len();
        let events = app.log.len();
        let home = apply_plan(&mut app, "stronglifts");
        assert_eq!(home.templates.len(), count);
        assert_eq!(app.log.len(), events + 1, "only the reorder");
        assert_eq!(home.current_plan_id, "stronglifts");
        assert_eq!(
            sections(&home),
            (
                vec!["StrongLifts A".into(), "StrongLifts B".into()],
                vec![
                    "Push".into(),
                    "My Pull".into(),
                    "Legs".into(),
                    "Arms".into()
                ],
            ),
        );
    }

    /// An unknown plan records nothing.
    #[test]
    fn applying_an_unknown_plan_fails() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let events = app.log.len();
        let err = app
            .call()
            .apply_library_plan(ApplyLibraryPlanRequest {
                plan_id: "nope".into(),
            })
            .unwrap_err();
        assert!(matches!(err, CoreError::NotFound(_)), "{err:?}");
        assert_eq!(app.log.len(), events);
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
                ..Default::default()
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

    /// A library template can go straight into the rotation; without
    /// saying so it is a reserve.
    #[test]
    fn a_library_template_can_be_added_into_the_rotation() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["full_body".into()],
                in_rotation: true,
                ..Default::default()
            })
            .unwrap();
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["arms".into()],
                ..Default::default()
            })
            .unwrap();
        let after = home(&mut app);
        let full_body = by_library(&after, "full_body");
        assert!(full_body.in_rotation && full_body.coupled);
        assert!(!by_library(&after, "arms").in_rotation);
    }

    /// A template cloned from the library keeps where it came from, and
    /// the entry is never added again beside it, into the rotation or not.
    #[test]
    fn a_personalised_copy_is_not_offered_again() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        let b = by_library(&onboarded, "stronglifts_b");
        let cloned = app
            .call()
            .save_template(SaveTemplateRequest {
                template: Some(b.clone()),
                unlink: true,
            })
            .unwrap()
            .template
            .unwrap();
        assert!(!cloned.coupled && cloned.library_id.is_empty());
        assert_eq!(cloned.origin_library_id, "stronglifts_b");
        // Edited after, it is still the one made from the entry.
        let mut edited = cloned.clone();
        edited.name = "Legs, mine".into();
        app.call()
            .save_template(SaveTemplateRequest {
                template: Some(edited),
                ..Default::default()
            })
            .unwrap();
        assert!(app.account.has_library_entry("stronglifts_b"));
        let events = app.log.len();
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["stronglifts_b".into()],
                in_rotation: true,
                ..Default::default()
            })
            .unwrap();
        let after = app.view().home(0);
        assert_eq!(after.templates.len(), onboarded.templates.len());
        assert_eq!(app.log.len(), events);
    }

    /// Home's rotation check names what each reserve and each library
    /// entry the user does not have would add: the muscles its lifts train
    /// first that the rotation trains none of. One adding nothing, and an
    /// entry the user has, are not listed.
    #[test]
    fn the_check_names_what_each_workout_would_add() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        let adds = |home: &GetHomeResponse, template_id: &str, library_id: &str| {
            home.rotation_check
                .as_ref()
                .unwrap()
                .additions
                .iter()
                .find(|a| a.template_id == template_id && a.library_id == library_id)
                .map(|a| a.muscles.clone())
        };
        let calves = MuscleGroup::Calves as i32;
        let core = MuscleGroup::Core as i32;
        // StrongLifts A and B train neither calves nor core.
        assert_eq!(adds(&onboarded, "", "lower"), Some(vec![calves, core]));
        assert_eq!(adds(&onboarded, "", "core"), Some(vec![core]));
        assert_eq!(adds(&onboarded, "", "big_three"), None, "adds nothing");

        // Core into the rotation, Legs as a reserve.
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["core".into()],
                in_rotation: true,
                ..Default::default()
            })
            .unwrap();
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["legs".into()],
                ..Default::default()
            })
            .unwrap();
        let after = home(&mut app);
        let legs = by_library(&after, "legs").id;
        assert_eq!(adds(&after, "", "lower"), Some(vec![calves]));
        assert_eq!(adds(&after, &legs, ""), Some(vec![calves]));
        assert_eq!(adds(&after, "", "core"), None, "the user has it");
        assert_eq!(adds(&after, "", "legs"), None, "the user has it");
        assert!(after
            .rotation_check
            .unwrap()
            .additions
            .iter()
            .all(|a| a.template_id != by_library(&onboarded, "stronglifts_a").id));
    }

    /// The Manage sheet's drag: one reorder that also splits the list into
    /// the rotation and the reserves; without the split only the order
    /// changes. Library templates moved keep following the library.
    #[test]
    fn a_reorder_can_move_templates_between_rotation_and_reserves() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["arms".into()],
                ..Default::default()
            })
            .unwrap();
        let a = by_library(&onboarded, "stronglifts_a").id;
        let b = by_library(&onboarded, "stronglifts_b").id;
        let arms = by_library(&home(&mut app), "arms").id;
        // Arms to the top of the rotation, B down to the reserves.
        app.call()
            .reorder_templates(ReorderTemplatesRequest {
                template_ids: vec![arms.clone(), a.clone(), b.clone()],
                rotation_count: Some(2),
            })
            .unwrap();
        let after = home(&mut app);
        let order: Vec<(&str, bool)> = after
            .templates
            .iter()
            .map(|t| (t.id.as_str(), t.in_rotation))
            .collect();
        assert_eq!(
            order,
            vec![
                (arms.as_str(), true),
                (a.as_str(), true),
                (b.as_str(), false)
            ]
        );
        assert!(after.templates.iter().all(|t| t.coupled));

        // Order alone leaves the split as it is.
        app.call()
            .reorder_templates(ReorderTemplatesRequest {
                template_ids: vec![b.clone(), a.clone(), arms.clone()],
                ..Default::default()
            })
            .unwrap();
        let after = home(&mut app);
        let order: Vec<(&str, bool)> = after
            .templates
            .iter()
            .map(|t| (t.id.as_str(), t.in_rotation))
            .collect();
        assert_eq!(
            order,
            vec![
                (b.as_str(), false),
                (a.as_str(), true),
                (arms.as_str(), true)
            ]
        );

        let err = app
            .call()
            .reorder_templates(ReorderTemplatesRequest {
                template_ids: vec![a],
                rotation_count: Some(-1),
            })
            .unwrap_err();
        assert!(matches!(err, CoreError::InvalidArgument(_)));
    }

    /// A reserve is never suggested, however far behind its muscles are.
    #[test]
    fn the_suggestion_comes_from_the_rotation() {
        let mut app = App::new();
        let onboarded = onboard(&mut app, WeightUnit::Lb);
        app.call()
            .add_library_templates(AddLibraryTemplatesRequest {
                library_ids: vec!["arms".into()],
                ..Default::default()
            })
            .unwrap();
        let after = home(&mut app);
        let rotation: Vec<&str> = onboarded.templates.iter().map(|t| t.id.as_str()).collect();
        assert!(rotation.contains(&after.suggested_template_id.as_str()));
    }
}

/// Discarding a workout, under way or finished, leaves the account as if it
/// never happened: no workout under way, nothing in history, and the log
/// still replays to the same account.
#[test]
fn a_discarded_workout_is_gone() {
    let mut app = App::new();
    let kept = start(&mut app, &[Exercise::Squat]);
    let end = finish(&mut app, &kept, |s| s.target_reps, NOW);
    app.call()
        .end_workout(EndWorkoutRequest {
            workout_id: kept.id.clone(),
            ended_at: end,
        })
        .unwrap();
    let tested = start(&mut app, &[Exercise::BenchPress]);
    app.call()
        .discard_workout(DiscardWorkoutRequest {
            workout_id: tested.id.clone(),
        })
        .unwrap();
    assert!(app.view().get_active_workout().workout.is_none());
    let finished = app.view().list_workout_summaries().workouts;
    assert_eq!(finished.len(), 1);
    assert_eq!(finished[0].workout.as_ref().unwrap().id, kept.id);

    app.call()
        .discard_workout(DiscardWorkoutRequest {
            workout_id: kept.id.clone(),
        })
        .unwrap();
    assert!(app.view().list_workout_summaries().workouts.is_empty());
    assert!(app
        .call()
        .discard_workout(DiscardWorkoutRequest {
            workout_id: kept.id.clone(),
        })
        .is_err());
}

/// One set of `started` done at `at`; returns it as recorded.
fn one_set(app: &mut App, started: &StartWorkoutResponse, at: i64) -> CompletedSet {
    let set = started.next_up_set.clone().unwrap();
    let state = app
        .call()
        .append_workout_mutations(AppendWorkoutMutationsRequest {
            mutations: vec![mutation(Mutation::CompleteSet(CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: set.target_reps,
                actual_weight: set.target_weight,
                completed_at: at,
            }))],
        })
        .unwrap()
        .workout_state
        .unwrap();
    state
        .completed_sets
        .into_iter()
        .find(|c| c.proposed_set_id == set.id)
        .unwrap()
}

fn end(app: &mut App, id: &str, at: i64) -> i64 {
    app.call()
        .end_workout(EndWorkoutRequest {
            workout_id: id.to_string(),
            ended_at: at,
        })
        .unwrap()
        .workout
        .unwrap()
        .end_time
}

/// A workout left running ends where the training did: its last set's end
/// plus that set's rest, at most five minutes. One ended sooner keeps its
/// time; one with nothing done ends when asked. The start always counts.
#[test]
fn a_workout_left_running_ends_after_its_last_set() {
    let mut app = App::new();
    let started = start(&mut app, &[Exercise::Squat]);
    let done = one_set(&mut app, &started, NOW + 120);
    let rest = (done.rest_until - done.ended_at).min(300);
    assert!(rest > 0);
    let ended = end(&mut app, &started.id, NOW + 3 * 3600);
    assert_eq!(ended, done.ended_at + rest);
    let workout = app
        .view()
        .list_workout_summaries()
        .workouts
        .remove(0)
        .workout
        .unwrap();
    assert_eq!(workout.start_time, started.workout.unwrap().start_time);

    let mut app = App::new();
    let started = start(&mut app, &[Exercise::Squat]);
    let done = one_set(&mut app, &started, NOW + 120);
    assert_eq!(
        end(&mut app, &started.id, done.ended_at + 30),
        done.ended_at + 30
    );

    let mut app = App::new();
    let started = start(&mut app, &[Exercise::Squat]);
    assert_eq!(end(&mut app, &started.id, NOW + 3 * 3600), NOW + 3 * 3600);
}

/// Heart rate past the end is left out, and moving the end earlier takes
/// the readings after it with it. Only an ended workout's end moves.
#[test]
fn heart_rate_stays_within_the_workout() {
    let mut app = App::new();
    let started = start(&mut app, &[Exercise::Squat]);
    let start_ms = started.workout.as_ref().unwrap().start_time * 1000;
    assert!(app.call().move_workout_end(&started.id, NOW).is_err());
    let done = one_set(&mut app, &started, NOW + 120);
    let ended = end(&mut app, &started.id, NOW + 3 * 3600);
    let at = |ms: i64| WorkoutHeartRatePoint {
        sampled_at: ms,
        bpm: 120.0,
    };
    app.call()
        .record_heart_rate(
            &started.id,
            &[
                at(start_ms - 5_000),
                at(start_ms + 1_000),
                at(done.ended_at * 1000),
                at(ended * 1000 + 60_000),
            ],
        )
        .unwrap();
    let samples = |app: &mut App| {
        app.view()
            .get_workout_heart_rate(GetWorkoutHeartRateRequest {
                workout_id: started.id.clone(),
            })
            .unwrap()
            .samples
            .len()
    };
    assert_eq!(samples(&mut app), 2, "only those within the workout");
    app.call().move_workout_end(&started.id, NOW + 60).unwrap();
    assert_eq!(
        samples(&mut app),
        1,
        "the end moved, the later reading with it"
    );
}

/// One batch of changes, its response.
fn batch(app: &mut App, mutations: Vec<WorkoutMutation>) -> AppendWorkoutMutationsResponse {
    app.call()
        .append_workout_mutations(AppendWorkoutMutationsRequest { mutations })
        .unwrap()
}

fn complete_set(set: &ProposedSet, reps: i32, weight: f32, at: i64) -> WorkoutMutation {
    mutation(Mutation::CompleteSet(CompleteSetRequest {
        workout_id: set.workout_id.clone(),
        proposed_set_id: set.id.clone(),
        actual_reps: reps,
        actual_weight: weight,
        completed_at: at,
    }))
}

mod refused_writes {
    use super::*;

    /// An empty mutation (or a kind this build doesn't know) is skipped
    /// like any other that can't apply: the rest of the batch still lands.
    #[test]
    fn an_empty_mutation_is_skipped() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::LateralRaise]);
        let set = started.proposed_sets[0].clone();
        let state = batch(
            &mut app,
            vec![
                complete_set(&set, 10, 20.0, NOW + 100),
                WorkoutMutation { mutation: None },
            ],
        )
        .workout_state
        .unwrap();
        assert_eq!(state.completed_sets.len(), 1);
        assert_eq!(app.log.len(), 3, "onboarding, the start and the set");
    }

    /// A done set with negative reps or a negative or non-finite weight
    /// fails the batch and records nothing. A weight past an edit's 2000
    /// is taken: the planner can propose one.
    #[test]
    fn a_done_set_out_of_range_is_refused() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        import_session(
            &mut app,
            Exercise::LateralRaise,
            20.0,
            10,
            &[10, 10],
            NOW - DAY,
        );
        let started = start(&mut app, &[Exercise::LateralRaise]);
        let set = working(&started.proposed_sets, Exercise::LateralRaise)[0].clone();
        let logged = app.log.len();
        for (reps, weight) in [(10, f32::NAN), (10, f32::INFINITY), (10, -1.0), (-1, 20.0)] {
            let refused = app
                .call()
                .append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![complete_set(&set, reps, weight, NOW + 100)],
                });
            assert!(refused.is_err(), "{reps} x {weight}");
        }
        assert_eq!(app.log.len(), logged, "nothing recorded");
        // The bounds themselves are fine, and so is a weight past 2000.
        for (n, weight) in [0.0, 3000.0].into_iter().enumerate() {
            let set = working(&started.proposed_sets, Exercise::LateralRaise)[n].clone();
            batch(&mut app, vec![complete_set(&set, 0, weight, NOW + 200)]);
        }
        assert_eq!(app.log.len(), logged + 2);
    }

    /// A rung whose append has been lifted is not undone: undone, it would
    /// keep that append, and done again append a second time.
    #[test]
    fn a_rung_whose_append_was_lifted_is_not_undone() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::Squat]);
        let rung1 = started.proposed_sets[0].clone();
        let state = batch(
            &mut app,
            vec![complete_set(&rung1, 5, rung1.target_weight, NOW + 100)],
        )
        .workout_state
        .unwrap();
        let rung2 = state.proposed_sets[1].clone();
        assert!(rung2.calibration);
        let state = batch(
            &mut app,
            vec![complete_set(&rung2, 3, rung2.target_weight, NOW + 300)],
        )
        .workout_state
        .unwrap();
        let done_id = |state: &GetWorkoutResponse, set: &ProposedSet| {
            state
                .completed_sets
                .iter()
                .find(|c| c.proposed_set_id == set.id)
                .unwrap()
                .id
                .clone()
        };
        let rung2_done = done_id(&state, &rung2);
        let undo = |id: &str| {
            mutation(Mutation::DeleteCompletedSet(DeleteCompletedSetRequest {
                workout_id: started.id.clone(),
                completed_set_id: id.to_string(),
            }))
        };

        // Before any of its append is lifted, the rung can be undone (and
        // takes the append back); done again, it appends once.
        let undone = batch(&mut app, vec![undo(&rung2_done)])
            .workout_state
            .unwrap();
        assert!(working(&undone.proposed_sets, Exercise::Squat).is_empty());
        let state = batch(
            &mut app,
            vec![complete_set(&rung2, 3, rung2.target_weight, NOW + 400)],
        )
        .workout_state
        .unwrap();
        let rung2_done = done_id(&state, &rung2);
        let sets = working(&state.proposed_sets, Exercise::Squat);
        assert!(!sets.is_empty());

        let lifted = batch(
            &mut app,
            vec![complete_set(&sets[0], 5, sets[0].target_weight, NOW + 600)],
        )
        .workout_state
        .unwrap();
        let logged = app.log.len();
        let rung1_done = done_id(&lifted, &rung1);
        for id in [&rung2_done, &rung1_done] {
            let refused = app
                .call()
                .append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![undo(id)],
                });
            assert!(refused.is_err(), "the undo fails the call");
        }
        assert_eq!(app.log.len(), logged, "both refused");
        let after = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: started.id.clone(),
            })
            .unwrap();
        assert_eq!(after.proposed_sets, lifted.proposed_sets);
        assert_eq!(after.completed_sets, lifted.completed_sets);
    }

    /// A lift removed before any set and added again is planned around
    /// once, by its latest decision: its first log is not counted again.
    #[test]
    fn a_lift_added_back_counts_once_in_the_budget() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        for exercise in [Exercise::Squat, Exercise::BarbellRow, Exercise::BenchPress] {
            import_session(&mut app, exercise, 95.0, 5, &[5, 5, 5], NOW - DAY);
        }
        let started = app
            .call()
            .start_workout(StartWorkoutRequest {
                exercises: vec![Exercise::Squat as i32, Exercise::BarbellRow as i32],
                budget_minutes: 75,
                ..Default::default()
            })
            .unwrap();
        let add = |exercise: Exercise| {
            mutation(Mutation::AddExercises(AddExercisesRequest {
                workout_id: started.id.clone(),
                exercises: vec![exercise as i32],
                ..Default::default()
            }))
        };
        batch(
            &mut app,
            vec![
                mutation(Mutation::RemoveExercise(RemoveExerciseRequest {
                    workout_id: started.id.clone(),
                    exercise: Exercise::Squat as i32,
                })),
                add(Exercise::Squat),
            ],
        );
        let record = app.account.workout(&started.id).unwrap();
        assert_eq!(record.exercise_logs.len(), 3, "squat has two logs");
        let planned: Vec<ExerciseDecision> = [Exercise::BarbellRow, Exercise::Squat]
            .iter()
            .map(|ex| record.decision(*ex as i32).cloned().unwrap())
            .collect();
        let expected = schlift_core::plan::Planner::new(&app.account, app.now)
            .workout(&[Exercise::BenchPress], &planned, 75)
            .pop()
            .unwrap();
        batch(&mut app, vec![add(Exercise::BenchPress)]);
        let bench = app
            .account
            .workout(&started.id)
            .unwrap()
            .decision(Exercise::BenchPress as i32)
            .cloned()
            .unwrap();
        assert_eq!(bench, expected);
    }
}

mod settings {
    use super::*;
    use schlift_core::weight_units::{snap_loadable_lb, AppWeightUnit};

    fn set(app: &mut App, setting: user_setting::Setting) {
        app.call()
            .update_setting(UpdateSettingRequest {
                setting: Some(UserSetting {
                    setting: Some(setting),
                }),
            })
            .unwrap();
    }

    fn unit(unit: WeightUnit) -> user_setting::Setting {
        user_setting::Setting::WeightUnit(WeightUnitConfig { unit: unit as i32 })
    }

    fn plates(n: usize) -> user_setting::Setting {
        user_setting::Setting::PlateColors(PlateColorsConfig {
            plates: vec![PlateColor::default(); n],
        })
    }

    /// One setting of each kind: a new one replaces only its own kind.
    #[test]
    fn a_setting_replaces_only_its_own_kind() {
        let mut app = App::new();
        set(&mut app, plates(1));
        set(&mut app, unit(WeightUnit::Kg));
        set(&mut app, plates(2));
        let settings = app.view().get_settings().settings;
        assert_eq!(settings.len(), 2);
        assert!(settings.contains(&UserSetting {
            setting: Some(plates(2))
        }));
        assert!(settings.contains(&UserSetting {
            setting: Some(unit(WeightUnit::Kg))
        }));
    }

    /// A setting with nothing in it is refused and records nothing.
    #[test]
    fn an_empty_setting_is_refused() {
        let mut app = App::new();
        for setting in [None, Some(UserSetting { setting: None })] {
            let refused = app
                .call()
                .update_setting(UpdateSettingRequest { setting })
                .unwrap_err();
            assert!(matches!(refused, CoreError::InvalidArgument(_)));
        }
        assert!(app.log.is_empty());
        assert!(app.account.settings.is_empty());
    }

    /// A workout keeps rounding in the unit it started in when the unit
    /// changes while it runs; the next one starts in the new unit, and
    /// history imported after the change reads in it.
    #[test]
    fn a_unit_change_mid_workout_keeps_the_workouts_unit() {
        // A squat started in `started_in`, moved to 137 lb (its warmups
        // laid out again), with the unit changed first or not.
        let moved = |started_in: WeightUnit, change: Option<WeightUnit>| {
            let mut app = App::new();
            onboard(&mut app, started_in);
            import_session(&mut app, Exercise::Squat, 135.0, 5, &[5, 5, 5], NOW - DAY);
            let started = start(&mut app, &[Exercise::Squat]);
            if let Some(change) = change {
                set(&mut app, unit(change));
            }
            let state = batch(
                &mut app,
                vec![mutation(Mutation::AdjustExerciseWeight(
                    AdjustExerciseWeightRequest {
                        workout_id: started.id.clone(),
                        exercise: Exercise::Squat as i32,
                        working_weight: 137.0,
                        target_reps: 0,
                    },
                ))],
            )
            .workout_state
            .unwrap();
            let weights: Vec<f32> = state
                .proposed_sets
                .iter()
                .map(|s| s.target_weight)
                .collect();
            (app, started, weights)
        };
        let (_, _, in_lb) = moved(WeightUnit::Lb, None);
        let (_, _, in_kg) = moved(WeightUnit::Kg, None);
        assert_ne!(in_lb, in_kg, "the warmups round differently in kg");
        let (mut app, started, changed) = moved(WeightUnit::Lb, Some(WeightUnit::Kg));
        assert_eq!(changed, in_lb, "still rounds in lb");
        app.call()
            .end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: NOW + 200,
            })
            .unwrap();

        app.now = NOW + DAY;
        let next = start(&mut app, &[Exercise::Squat]);
        assert_eq!(
            app.account.workout(&next.id).unwrap().unit,
            AppWeightUnit::Kg
        );
        for s in &next.proposed_sets {
            let kg = snap_loadable_lb(s.target_weight, AppWeightUnit::Kg);
            assert!((kg - s.target_weight).abs() < 1e-3, "{s:?}");
        }
        import_session(&mut app, Exercise::BenchPress, 95.0, 5, &[5], NOW - 2 * DAY);
        let imported = app
            .account
            .workouts
            .iter()
            .find(|r| r.workout.end_time == NOW - 2 * DAY)
            .unwrap();
        assert_eq!(imported.unit, AppWeightUnit::Kg);
        assert_eq!(
            app.account.workout(&started.id).unwrap().unit,
            AppWeightUnit::Lb
        );
    }

    /// The rung question's buttons show what each answer gives in the
    /// workout's unit too, not the one the settings changed to since.
    #[test]
    fn a_unit_change_mid_ramp_keeps_what_each_answer_shows() {
        // A fresh squat ramp started in lb, its first rung done, the unit
        // then set to `now_in`: what each answer is shown to lead to.
        let asked = |now_in: WeightUnit| {
            let mut app = App::new();
            onboard(&mut app, WeightUnit::Lb);
            let started = start(&mut app, &[Exercise::Squat]);
            let rung = started.proposed_sets[0].clone();
            batch(
                &mut app,
                vec![complete_set(&rung, 5, rung.target_weight, NOW + 60)],
            );
            set(&mut app, unit(now_in));
            let outcomes = app
                .view()
                .get_workout(GetWorkoutRequest {
                    workout_id: started.id.clone(),
                })
                .unwrap()
                .rung_outcomes;
            assert_eq!(outcomes.len(), 3);
            (app, started, rung, outcomes)
        };
        let (_, _, _, in_lb) = asked(WeightUnit::Lb);
        let (_, _, _, changed) = asked(WeightUnit::Kg);
        assert_eq!(changed, in_lb, "still snapped in lb");
        for shown in &changed {
            let (mut app, started, rung, _) = asked(WeightUnit::Kg);
            let state = batch(
                &mut app,
                vec![mutation(Mutation::AnswerRung(AnswerRungRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: rung.id.clone(),
                    reps_left: shown.reps_left,
                    jump_lb: 0.0,
                }))],
            )
            .workout_state
            .unwrap();
            let next = state
                .proposed_sets
                .iter()
                .find(|s| {
                    s.exercise == Exercise::Squat as i32
                        && !s.warmup
                        && !s.cancelled
                        && state
                            .completed_sets
                            .iter()
                            .all(|c| c.proposed_set_id != s.id)
                })
                .unwrap();
            assert_eq!(next.target_weight, shown.weight, "{shown:?}");
        }
    }

    /// Onboarding again without a unit keeps the one set.
    #[test]
    fn onboarding_again_without_a_unit_keeps_it() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Kg);
        onboard(&mut app, WeightUnit::Unspecified);
        assert_eq!(app.account.unit(), AppWeightUnit::Kg);
    }
}

mod imports {
    use super::*;

    fn imported(id: &str, end: i64, exercise: Exercise, weight: f32) -> ImportedWorkout {
        let set_id = format!("{id}:0");
        ImportedWorkout {
            workout: Some(Workout {
                id: id.to_string(),
                name: "Imported".into(),
                start_time: end - 3600,
                end_time: end,
                ..Default::default()
            }),
            proposed_sets: vec![ProposedSet {
                id: set_id.clone(),
                workout_id: id.to_string(),
                exercise: exercise as i32,
                target_reps: 5,
                target_weight: weight,
                ..Default::default()
            }],
            completed_sets: vec![CompletedSet {
                id: format!("{set_id}:done"),
                workout_id: id.to_string(),
                proposed_set_id: set_id,
                actual_reps: 5,
                actual_weight: weight,
                ended_at: end - 600,
                ..Default::default()
            }],
            ..Default::default()
        }
    }

    fn import(app: &mut App, workouts: Vec<ImportedWorkout>, starting: Vec<ExerciseWeight>) {
        app.call()
            .import_history(ImportHistory {
                workouts,
                starting_weights: starting,
            })
            .unwrap();
    }

    /// An import lands in time order among the workouts already held, once
    /// (a workout id already held is not imported again), with its heart
    /// rate and the starting weights it brings.
    #[test]
    fn an_import_is_folded_once_and_in_time_order() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let first = start(&mut app, &[Exercise::LateralRaise]);
        finish(&mut app, &first, |s| s.target_reps, NOW + 60);
        let running = start(&mut app, &[Exercise::LateralRaise]);

        let mut w1 = imported("W1", NOW - 10 * DAY, Exercise::Squat, 135.0);
        w1.heart_rate = vec![WorkoutHeartRatePoint {
            sampled_at: (NOW - 10 * DAY - 1800) * 1000,
            bpm: 120.0,
        }];
        let w0 = imported("W0", NOW - 20 * DAY, Exercise::Squat, 125.0);
        import(
            &mut app,
            vec![w1, w0, ImportedWorkout::default()],
            vec![ExerciseWeight {
                exercise: Exercise::Squat as i32,
                weight_lb: 155.0,
            }],
        );
        let starts: Vec<i64> = app
            .account
            .workouts
            .iter()
            .map(|r| r.workout.start_time)
            .collect();
        assert!(starts.windows(2).all(|w| w[0] <= w[1]), "{starts:?}");
        assert_eq!(
            app.account.workouts.len(),
            4,
            "an entry with no workout adds nothing"
        );
        assert_eq!(app.view().list_workout_summaries().workouts.len(), 3);
        assert_eq!(
            app.account.starting_weights[&(Exercise::Squat as i32)],
            155.0
        );
        assert_eq!(app.account.active_workout_id, running.id);
        let samples = app
            .view()
            .get_workout_heart_rate(GetWorkoutHeartRateRequest {
                workout_id: "W1".into(),
            })
            .unwrap()
            .samples;
        assert_eq!(samples.len(), 1);

        // Sent again, changed: the one held stays as it was.
        let before = app.account.workout("W1").unwrap().clone();
        import(
            &mut app,
            vec![imported("W1", NOW - 5 * DAY, Exercise::BenchPress, 95.0)],
            vec![],
        );
        assert_eq!(app.account.workout("W1").unwrap(), &before);
        assert_eq!(app.account.workouts.len(), 4);
        assert_eq!(
            app.account.active_workout().map(|r| r.workout.id.clone()),
            Some(running.id.clone())
        );
    }
}

mod overrides {
    use super::*;

    fn set(app: &mut App, exercise: i32, weight: f32, reps: i32, sets: Option<i32>) -> bool {
        app.call()
            .set_override(SetOverrideRequest {
                exercise,
                weight,
                reps,
                sets,
            })
            .map_err(|e| assert!(matches!(e, CoreError::InvalidArgument(_)), "{e:?}"))
            .is_ok()
    }

    /// The bounds an override must be within, which decide which stored
    /// overrides fold.
    #[test]
    fn override_limits() {
        let squat = Exercise::Squat as i32;
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        for (weight, reps, sets) in [
            (0.0, 5, None),
            (2000.0, 5, None),
            (100.0, 100, Some(1)),
            (100.0, 5, Some(20)),
        ] {
            assert!(
                set(&mut app, squat, weight, reps, sets),
                "{weight} {reps} {sets:?}"
            );
        }
        let held = app.account.overrides.clone();
        let logged = app.log.len();
        for (exercise, weight, reps, sets) in [
            (squat, 2000.5, 5, None),
            (squat, -1.0, 5, None),
            (squat, f32::NAN, 5, None),
            (squat, 100.0, 101, None),
            (squat, 100.0, 5, Some(0)),
            (squat, 100.0, 5, Some(21)),
            (0, 100.0, 5, None),
            (9999, 100.0, 5, None),
        ] {
            assert!(
                !set(&mut app, exercise, weight, reps, sets),
                "{exercise} {weight} {reps} {sets:?}"
            );
            assert_eq!(app.account.overrides, held);
            assert_eq!(app.log.len(), logged);
        }
        // Reps of 0 or less remove it, whatever the weight.
        assert!(set(&mut app, squat, 99999.0, -1, None));
        assert!(!app.account.overrides.contains_key(&squat));
    }
}

mod heart_rate_fold {
    use super::*;
    use schlift_core::events::HeartRateRecorded;

    fn event(id: &str, fact: Fact) -> Event {
        Event {
            seq: 0,
            id: id.to_string(),
            at: NOW,
            fact,
        }
    }

    /// Heart rate folds as recorded: a second recording replaces the first,
    /// gaps that don't match the readings are refused, and a workout not
    /// held is not found.
    #[test]
    fn heart_rate_events_fold_as_recorded() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::LateralRaise]);
        let start_ms = app.account.workout(&started.id).unwrap().workout.start_time * 1000;
        let at = |ms: i64, bpm: f32| WorkoutHeartRatePoint {
            sampled_at: start_ms + ms,
            bpm,
        };
        app.call()
            .record_heart_rate(&started.id, &[at(1_000, 100.0), at(2_000, 110.0)])
            .unwrap();
        app.call()
            .record_heart_rate(&started.id, &[at(3_000, 120.0)])
            .unwrap();
        assert_eq!(
            app.account.workout(&started.id).unwrap().heart_rate,
            vec![at(3_000, 120.0)],
            "the second replaces the first"
        );

        let mut bad = HeartRateRecorded::new(&started.id, &[at(1_000, 100.0)]);
        bad.gaps_ms.push(5);
        let mut account = app.account.clone();
        assert!(matches!(
            account.apply(&event("bad", Fact::HeartRateRecorded(bad))),
            Err(CoreError::InvalidArgument(_))
        ));
        assert_eq!(account, app.account);

        let refused = app
            .call()
            .record_heart_rate("nope", &[at(1_000, 100.0)])
            .unwrap_err();
        assert!(matches!(refused, CoreError::NotFound(_)));
        let unknown = HeartRateRecorded::new("nope", &[at(1_000, 100.0)]);
        assert!(matches!(
            account.apply(&event("unknown", Fact::HeartRateRecorded(unknown))),
            Err(CoreError::NotFound(_))
        ));
    }
}

mod merges {
    use super::*;

    /// What a second device records, from the account as it last synced.
    fn on_device(
        log: &[Event],
        at: i64,
        write: impl FnOnce(&mut Call) -> Result<(), CoreError>,
    ) -> Vec<Event> {
        let mut account = Account::fold(log);
        let mut call = Call::new(&mut account, at, Uuid::new_v4().to_string());
        write(&mut call).unwrap();
        call.events
    }

    fn own_template(app: &mut App, name: &str) -> WorkoutTemplate {
        app.call()
            .save_template(SaveTemplateRequest {
                template: Some(WorkoutTemplate {
                    name: name.into(),
                    exercises: vec![Exercise::BarbellCurl as i32],
                    ..Default::default()
                }),
                unlink: false,
            })
            .unwrap()
            .template
            .unwrap()
    }

    /// One device deletes a template while another, offline, edits it. A
    /// save placed after the delete brings the template back, created anew
    /// at the save; a delete placed after the save removes it. Pinned as it
    /// is: a change to it is a change to every stored account.
    #[test]
    fn a_save_after_a_delete_keeps_the_template() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let arms = own_template(&mut app, "Arms");
        let synced = app.log.clone();
        let deleted = on_device(&synced, NOW + 10, |call| {
            call.delete_template(DeleteTemplateRequest {
                template_id: arms.id.clone(),
            })
            .map(|_| ())
        });
        let saved = on_device(&synced, NOW + 20, |call| {
            let mut edited = arms.clone();
            edited.name = "Big arms".into();
            call.save_template(SaveTemplateRequest {
                template: Some(edited),
                unlink: false,
            })
            .map(|_| ())
        });

        let delete_then_save: Vec<Event> = synced
            .iter()
            .chain(&deleted)
            .chain(&saved)
            .cloned()
            .collect();
        let account = Account::fold(&delete_then_save);
        let back = account.template(&arms.id).expect("brought back");
        assert_eq!(back.name, "Big arms");
        assert_eq!(back.created_at, NOW + 20);

        let save_then_delete: Vec<Event> = synced
            .iter()
            .chain(&saved)
            .chain(&deleted)
            .cloned()
            .collect();
        assert!(Account::fold(&save_then_delete)
            .template(&arms.id)
            .is_none());
    }

    /// A reorder naming a template another device deleted skips that id;
    /// the others still take their place in the list (counted with the
    /// missing one) and the rotation count.
    #[test]
    fn a_reorder_naming_a_deleted_template_skips_it() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let gone = own_template(&mut app, "Gone");
        let ids: Vec<String> = app.account.templates.iter().map(|t| t.id.clone()).collect();
        let synced = app.log.clone();
        let deleted = on_device(&synced, NOW + 10, |call| {
            call.delete_template(DeleteTemplateRequest {
                template_id: gone.id.clone(),
            })
            .map(|_| ())
        });
        let mut order: Vec<String> = vec![gone.id.clone()];
        order.extend(ids.iter().rev().filter(|id| **id != gone.id).cloned());
        let reordered = on_device(&synced, NOW + 20, |call| {
            call.reorder_templates(ReorderTemplatesRequest {
                template_ids: order.clone(),
                rotation_count: Some(2),
            })
            .map(|_| ())
        });
        let log: Vec<Event> = synced
            .iter()
            .chain(&deleted)
            .chain(&reordered)
            .cloned()
            .collect();
        let account = Account::fold(&log);
        assert!(account.template(&gone.id).is_none());
        assert_eq!(
            account
                .templates
                .iter()
                .map(|t| t.id.clone())
                .collect::<Vec<_>>(),
            order[1..]
        );
        for (position, id) in order.iter().enumerate().skip(1) {
            let t = account.template(id).unwrap();
            assert_eq!(t.order, position as i32);
            assert_eq!(t.in_rotation, position < 2, "{id}");
        }
    }
}

mod sessions {
    use super::*;

    fn set_session(workout_id: &str, session_id: &str) -> WorkoutMutation {
        mutation(Mutation::SetSession(SetWorkoutSessionRequest {
            workout_id: workout_id.into(),
            session_id: session_id.into(),
        }))
    }

    /// Who a workout was trained with is set on it, and goes to partners.
    #[test]
    fn a_session_is_set_on_the_workout() {
        let mut app = App::new();
        onboard(&mut app, WeightUnit::Lb);
        let started = start(&mut app, &[Exercise::LateralRaise]);
        batch(&mut app, vec![set_session(&started.id, "s1")]);
        let read = app
            .view()
            .get_workout(GetWorkoutRequest {
                workout_id: started.id.clone(),
            })
            .unwrap();
        assert_eq!(read.workout.unwrap().session_id, "s1");
        let recorded = &app.log.last().unwrap().fact;
        assert!(matches!(recorded, Fact::SessionSet(_)));
        assert!(schlift_core::session::shared_with_partners(recorded));

        let logged = app.log.len();
        batch(&mut app, vec![set_session("nope", "s2")]);
        assert_eq!(app.log.len(), logged, "no such workout: nothing logged");
    }
}
