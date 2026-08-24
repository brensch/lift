//! API-level tests for the composable-workout loop, against a real
//! `ServerDb` in a temp directory and the real RPC handlers. These are the
//! seams unit tests miss: onboarding → home → start-from-template →
//! complete → end → tracker advanced → next home reflects it.

use super::*;
use crate::db::ServerDb;
use schlift::workout::v1::{
    CompleteOnboardingRequest, CompleteSetRequest, DeleteTemplateRequest, EndWorkoutRequest,
    ExperienceLevel, GetHomeRequest, ReorderTemplatesRequest, SaveTemplateRequest,
    SetExerciseTrackerRequest, StartWorkoutRequest, WeightUnit, WorkoutTemplate,
};

fn authed<T>(token: &str, msg: T) -> Request<T> {
    let mut req = Request::new(msg);
    req.metadata_mut()
        .insert("x-session-token", token.parse().unwrap());
    req
}

async fn setup() -> (ServerWorkoutService, String, String) {
    let dir = std::env::temp_dir().join(format!("lift-live-test-{}", Uuid::new_v4()));
    let db = ServerDb::new_in_dir(&dir).await.unwrap();
    let (user, token) = db
        .get_or_create_user_with_auth_session("tester")
        .await
        .unwrap();
    (ServerWorkoutService { db }, user.id, token)
}

async fn onboard(svc: &ServerWorkoutService, token: &str, unit: WeightUnit) -> GetHomeResponse {
    svc.complete_onboarding(authed(
        token,
        CompleteOnboardingRequest {
            body_weight_kg: 0.0,
            experience: ExperienceLevel::Unspecified as i32,
            unit: unit as i32,
        },
    ))
    .await
    .unwrap()
    .into_inner()
    .home
    .unwrap()
}

async fn home(svc: &ServerWorkoutService, token: &str) -> GetHomeResponse {
    svc.get_home(authed(token, GetHomeRequest {}))
        .await
        .unwrap()
        .into_inner()
}

fn tracker(home: &GetHomeResponse, exercise: Exercise) -> ExerciseTracker {
    home.trackers
        .iter()
        .find(|t| t.exercise == exercise as i32)
        .cloned()
        .expect("every exercise has a tracker")
}

/// Complete every working set of a workout at exactly the given reps.
async fn complete_all_working_sets(
    svc: &ServerWorkoutService,
    token: &str,
    workout_id: &str,
    sets: &[ProposedSet],
    reps_for: impl Fn(&ProposedSet) -> i32,
    weight_for: impl Fn(&ProposedSet) -> f32,
    start_ts: i64,
) -> i64 {
    let mut ts = start_ts;
    for set in sets.iter().filter(|s| !s.warmup && !s.cancelled) {
        svc.complete_set(authed(
            token,
            CompleteSetRequest {
                workout_id: workout_id.to_string(),
                proposed_set_id: set.id.clone(),
                actual_reps: reps_for(set),
                actual_weight: weight_for(set),
                completed_at: ts,
            },
        ))
        .await
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
    #[tokio::test]
    async fn a_fresh_user_gets_a_full_home() {
        let (svc, _user_id, token) = setup().await;
        let response = home(&svc, &token).await;

        assert!(!response.onboarded);
        assert!(response.templates.is_empty());
        assert_eq!(response.volume.len(), 10);
        assert_eq!(response.recovery.len(), 10);
        assert_eq!(
            response.trackers.len(),
            crate::exercise_catalog::all_exercises().len()
        );

        let squat = tracker(&response, Exercise::Squat);
        assert_eq!(squat.working_weight, 45.0, "empty bar opener");
        assert_eq!((squat.rep_range_low, squat.rep_range_high), (6, 10));
        assert_eq!(squat.target_reps, 6, "range bottom");
        assert!(squat.include_warmup);
        assert_eq!(squat.sets, 3);

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
    #[tokio::test]
    async fn onboarding_seeds_defaults_once() {
        let (svc, _user_id, token) = setup().await;
        let response = svc
            .complete_onboarding(authed(
                &token,
                CompleteOnboardingRequest {
                    body_weight_kg: 100.0,
                    experience: ExperienceLevel::Intermediate as i32,
                    unit: WeightUnit::Lb as i32,
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .home
            .unwrap();

        assert!(response.onboarded);
        assert_eq!(response.templates.len(), 6);
        let names: Vec<&str> = response
            .templates
            .iter()
            .map(|t| t.name.as_str())
            .collect();
        assert!(names.contains(&"Full Body") && names.contains(&"Push"));

        // 100 kg ≈ 220 lb × 0.95 squat ratio ≈ 210, snapped loadable.
        let squat = tracker(&response, Exercise::Squat);
        assert!(
            (squat.working_weight - 210.0).abs() <= 5.0,
            "bodyweight-scaled: {}",
            squat.working_weight
        );

        // Repeat call: idempotent, nothing duplicated.
        let again = onboard(&svc, &token, WeightUnit::Lb).await;
        assert_eq!(again.templates.len(), 6);
    }

    /// A kilogram user's weights land on the kilogram grid — the defect the
    /// old program-state unit read shipped for months.
    #[tokio::test]
    async fn a_kg_user_gets_kg_loadable_weights() {
        let (svc, _user_id, token) = setup().await;
        let response = svc
            .complete_onboarding(authed(
                &token,
                CompleteOnboardingRequest {
                    body_weight_kg: 90.0,
                    experience: ExperienceLevel::Intermediate as i32,
                    unit: WeightUnit::Kg as i32,
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .home
            .unwrap();

        let squat = tracker(&response, Exercise::Squat);
        let kg = crate::weight_units::pounds_to_kg(squat.working_weight);
        let on_grid = (kg / 2.5 - (kg / 2.5).round()).abs() < 0.01
            || ((kg - 20.0) / 2.5 - ((kg - 20.0) / 2.5).round()).abs() < 0.01;
        assert!(on_grid, "squat resolves to a loadable kg value: {kg} kg");
    }
}

mod templates {
    use super::*;

    fn template(name: &str, exercises: &[Exercise]) -> WorkoutTemplate {
        WorkoutTemplate {
            name: name.to_string(),
            exercises: exercises.iter().map(|e| *e as i32).collect(),
            ..Default::default()
        }
    }

    #[tokio::test]
    async fn save_edit_reorder_delete() {
        let (svc, _user_id, token) = setup().await;

        let saved = svc
            .save_template(authed(
                &token,
                SaveTemplateRequest {
                    template: Some(template("Arms", &[Exercise::BarbellCurl, Exercise::SkullCrusher])),
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .template
            .unwrap();
        assert!(!saved.id.is_empty());

        // Edit keeps the id and order.
        let mut edited = saved.clone();
        edited.exercises.push(Exercise::HammerCurl as i32);
        let edited = svc
            .save_template(authed(&token, SaveTemplateRequest { template: Some(edited) }))
            .await
            .unwrap()
            .into_inner()
            .template
            .unwrap();
        assert_eq!(edited.id, saved.id);
        assert_eq!(edited.exercises.len(), 3);

        let second = svc
            .save_template(authed(
                &token,
                SaveTemplateRequest {
                    template: Some(template("Legs", &[Exercise::Squat])),
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .template
            .unwrap();

        // Reorder: Legs first.
        svc.reorder_templates(authed(
            &token,
            ReorderTemplatesRequest {
                template_ids: vec![second.id.clone(), saved.id.clone()],
            },
        ))
        .await
        .unwrap();
        let listed = home(&svc, &token).await.templates;
        assert_eq!(listed[0].name, "Legs");
        assert_eq!(listed[1].name, "Arms");

        svc.delete_template(authed(
            &token,
            DeleteTemplateRequest {
                template_id: saved.id.clone(),
            },
        ))
        .await
        .unwrap();
        assert_eq!(home(&svc, &token).await.templates.len(), 1);
    }

    #[tokio::test]
    async fn an_empty_template_is_rejected() {
        let (svc, _user_id, token) = setup().await;
        let err = svc
            .save_template(authed(
                &token,
                SaveTemplateRequest {
                    template: Some(template("Empty", &[])),
                },
            ))
            .await
            .unwrap_err();
        assert_eq!(err.code(), tonic::Code::InvalidArgument);
    }
}

mod template_workout_loop {
    use super::*;

    /// The whole point of the refactor, end to end: start from a template
    /// (server resolves weights + prescription + warmups), top the rep
    /// range, end the workout, and the next home shows the increased
    /// weight — on every template containing the exercise.
    #[tokio::test]
    async fn topping_the_range_moves_the_weight_for_next_time() {
        let (svc, _user_id, token) = setup().await;
        let before = onboard(&svc, &token, WeightUnit::Lb).await;
        let lower = before
            .templates
            .iter()
            .find(|t| t.name == "Lower")
            .unwrap()
            .clone();
        let squat_before = tracker(&before, Exercise::Squat).working_weight;

        let started = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: 1_000,
                    template_id: lower.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout = started.workout.unwrap();
        assert_eq!(workout.name, "Lower", "named after the template");

        // The squat group: tracker weight, prescription reps, a warmup
        // ladder (barbell compound). The crunch group: no warmups.
        let squat_sets: Vec<&ProposedSet> = started
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Squat as i32)
            .collect();
        assert_eq!(squat_sets.iter().filter(|s| s.warmup).count(), 4);
        let squat_working: Vec<&&ProposedSet> =
            squat_sets.iter().filter(|s| !s.warmup).collect();
        assert_eq!(squat_working.len(), 3);
        assert!(squat_working
            .iter()
            .all(|s| s.target_weight == squat_before && s.target_reps == 6));
        assert!(started
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == Exercise::Crunch as i32)
            .all(|s| !s.warmup));

        // Clear everything at the top of each range.
        let home_ref = &before;
        let ts = complete_all_working_sets(
            &svc,
            &token,
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
        )
        .await;

        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        let after = home(&svc, &token).await;
        let squat_after = tracker(&after, Exercise::Squat);
        assert_eq!(
            squat_after.working_weight,
            squat_before + 5.0,
            "one barbell step up"
        );
        assert_eq!(squat_after.target_reps, 6, "reps reset to the bottom");
        assert_eq!(squat_after.last_performed_at, ts, "stamped with the end time");

        // Bodyweight-free check on a dumbbell move from the same session:
        // calf raise topped its range too, so it took a dumbbell step.
        let calf_after = tracker(&after, Exercise::CalfRaise);
        assert_eq!(calf_after.working_weight, 25.0, "20 + one dumbbell step");
    }

    /// Clearing below the top of the range moves the rep target, not the
    /// weight.
    #[tokio::test]
    async fn clearing_mid_range_moves_reps_not_weight() {
        let (svc, _user_id, token) = setup().await;
        let before = onboard(&svc, &token, WeightUnit::Lb).await;
        let legs = before.templates.iter().find(|t| t.name == "Legs").unwrap();

        let started = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: 1_000,
                    template_id: legs.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout = started.workout.unwrap();

        // Exactly the target on every set (target = range bottom on day 1).
        let ts = complete_all_working_sets(
            &svc,
            &token,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            2_000,
        )
        .await;
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        let after = home(&svc, &token).await;
        let squat = tracker(&after, Exercise::Squat);
        assert_eq!(squat.working_weight, 45.0, "weight holds");
        assert_eq!(squat.target_reps, 7, "6 cleared → aim 7");
    }

    /// A re-fired EndWorkout must not advance a tracker twice.
    #[tokio::test]
    async fn end_workout_is_idempotent() {
        let (svc, _user_id, token) = setup().await;
        let before = onboard(&svc, &token, WeightUnit::Lb).await;
        let legs = before.templates.iter().find(|t| t.name == "Legs").unwrap();

        let started = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: 1_000,
                    template_id: legs.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &svc,
            &token,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            2_000,
        )
        .await;

        for _ in 0..2 {
            svc.end_workout(authed(
                &token,
                EndWorkoutRequest {
                    workout_id: workout.id.clone(),
                    ended_at: ts,
                },
            ))
            .await
            .unwrap();
        }

        let after = home(&svc, &token).await;
        assert_eq!(
            tracker(&after, Exercise::Squat).target_reps,
            7,
            "advanced exactly once"
        );
    }

    /// A manual tracker write sticks and drives the next start.
    #[tokio::test]
    async fn a_manual_override_drives_the_next_start() {
        let (svc, _user_id, token) = setup().await;
        let before = onboard(&svc, &token, WeightUnit::Lb).await;
        let legs = before.templates.iter().find(|t| t.name == "Legs").unwrap();

        let set_response = svc
            .set_exercise_tracker(authed(
                &token,
                SetExerciseTrackerRequest {
                    exercise: Exercise::Squat as i32,
                    working_weight: 225.0,
                    override_sets: 5,
                    override_rep_low: 5,
                    override_rep_high: 8,
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .tracker
            .unwrap();
        assert_eq!(set_response.working_weight, 225.0);
        assert_eq!(set_response.sets, 5);
        assert!(set_response.overridden);

        let started = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: 1_000,
                    template_id: legs.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
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

    /// Time away reduces the weights offered at start — 80% after 30 days —
    /// without ever writing the reduction to the tracker.
    #[tokio::test]
    async fn a_layoff_reduces_the_start_weight_only() {
        let (svc, _user_id, token) = setup().await;
        let before = onboard(&svc, &token, WeightUnit::Lb).await;
        let legs = before.templates.iter().find(|t| t.name == "Legs").unwrap();
        let day = 24 * 3600;
        let long_ago = 1_000_000;

        svc.set_exercise_tracker(authed(
            &token,
            SetExerciseTrackerRequest {
                exercise: Exercise::Squat as i32,
                working_weight: 200.0,
                override_sets: 0,
                override_rep_low: 0,
                override_rep_high: 0,
            },
        ))
        .await
        .unwrap();
        // Backdate the squat's last performance by writing a finished
        // session through the real loop at `long_ago`.
        let started = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: long_ago,
                    template_id: legs.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let first = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &svc,
            &token,
            &first.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            long_ago + 60,
        )
        .await;
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id: first.id.clone(),
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        let mid = home(&svc, &token).await;
        let squat_weight = tracker(&mid, Exercise::Squat).working_weight;
        assert_eq!(squat_weight, 200.0, "held after a bottom-of-range clear");

        // 40 days later: the offered weight is 80%, snapped; the tracker
        // itself is untouched.
        let resumed = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: ts + 40 * day,
                    template_id: legs.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let offered = resumed
            .proposed_sets
            .iter()
            .find(|s| s.exercise == Exercise::Squat as i32 && !s.warmup)
            .unwrap()
            .target_weight;
        assert_eq!(
            offered,
            crate::weight_units::snap_loadable_lb(160.0, crate::weight_units::AppWeightUnit::Lb),
            "80% after 30+ days away"
        );
        assert_eq!(
            tracker(&home(&svc, &token).await, Exercise::Squat).working_weight,
            200.0,
            "looking never writes"
        );
    }

    /// The suggestion points at the template covering the most-behind
    /// muscles, and names them.
    #[tokio::test]
    async fn the_suggestion_chases_the_deficit() {
        let (svc, _user_id, token) = setup().await;
        let before = onboard(&svc, &token, WeightUnit::Lb).await;
        let legs = before.templates.iter().find(|t| t.name == "Legs").unwrap();

        // Train legs now; every other muscle is behind.
        let started = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: String::new(),
                    exercise_groups: vec![],
                    started_at: now_unix() - 3600,
                    template_id: legs.id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout = started.workout.unwrap();
        let ts = complete_all_working_sets(
            &svc,
            &token,
            &workout.id,
            &started.proposed_sets,
            |set| set.target_reps,
            |set| set.target_weight,
            now_unix() - 3000,
        )
        .await;
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id: workout.id.clone(),
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        let after = home(&svc, &token).await;
        assert!(!after.suggested_template_id.is_empty());
        let suggested = after
            .templates
            .iter()
            .find(|t| t.id == after.suggested_template_id)
            .unwrap();
        assert_ne!(suggested.name, "Legs", "legs were just trained");
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
