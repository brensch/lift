use std::collections::HashMap;

use chrono::Utc;
use lift::workout::v1::{
    Exercise, ExerciseStatus, ProposedExerciseGroup, RegimeContext, UserWorkoutConfig,
};

use super::{
    build_single_group, exercise_display_name, make_exercise_type_config, rest_cfg, ExerciseConfig,
    ExerciseProposal, SessionHistory, WorkoutRegime,
};

const UPPER_INCREMENT: f32 = 5.0;
const LOWER_INCREMENT: f32 = 5.0;
const DEADLIFT_INCREMENT: f32 = 10.0;
const RECOVERY_HOURS: i64 = 48;

pub struct Linear5x5Regime;

impl WorkoutRegime for Linear5x5Regime {
    fn display_name(&self) -> &'static str {
        "Linear 5×5"
    }

    fn default_days_per_week(&self) -> i32 {
        3
    }

    fn recovery_seconds(&self, _workout_config: &UserWorkoutConfig) -> i64 {
        RECOVERY_HOURS * 3600
    }

    fn calculate_exercise_progression(
        &self,
        exercise: Exercise,
        config: &ExerciseConfig,
        history: &[SessionHistory],
        max_weight: f32,
        _workout_config: &UserWorkoutConfig,
    ) -> ExerciseProposal {
        let (weight, explanation) = calculate_linear_progression(
            exercise as i32,
            config.default_weight,
            history,
            max_weight,
        );
        ExerciseProposal {
            weight,
            sets: config.default_sets,
            reps: config.default_reps,
            explanation,
        }
    }

    fn build_proposed_groups(
        &self,
        statuses: &[ExerciseStatus],
        _workout_config: &UserWorkoutConfig,
    ) -> Vec<ProposedExerciseGroup> {
        build_linear_proposed_groups(statuses)
    }

    fn compute_updated_state(
        &self,
        _workout_config: &UserWorkoutConfig,
        _history: &HashMap<i32, Vec<SessionHistory>>,
    ) -> String {
        "{}".to_string()
    }

    fn build_regime_context(
        &self,
        _workout_config: &UserWorkoutConfig,
        _statuses: &[ExerciseStatus],
    ) -> RegimeContext {
        RegimeContext {
            regime_display_name: self.display_name().to_string(),
            session_description: "Linear progression — add weight every session".to_string(),
            next_session_preview: "Same exercises, 5 lbs heavier on upper body, 10 lbs on deadlift"
                .to_string(),
            coaching_notes: vec![
                "Focus on form before chasing weight.".to_string(),
                "If a set feels like a 9/10 effort, consider deloading proactively.".to_string(),
            ],
        }
    }
}

// ─── Core weight calculation (pure function, reusable) ────────────────────────

pub fn calculate_linear_progression(
    exercise: i32,
    default_weight: f32,
    history: &[SessionHistory], // newest-first
    max_weight: f32,
) -> (f32, String) {
    if history.is_empty() {
        return (
            default_weight,
            format!("Starting at {} lbs — welcome!", default_weight),
        );
    }

    let h = &history[0];
    let now = Utc::now().timestamp();
    let days_since = (now - h.timestamp) / (24 * 3600);

    let increment = if exercise == Exercise::Deadlift as i32 {
        DEADLIFT_INCREMENT
    } else if exercise == Exercise::Squat as i32 {
        LOWER_INCREMENT
    } else {
        UPPER_INCREMENT
    };

    // 1. Long break deload
    if days_since > 14 {
        let deload_pct = if days_since > 30 { 0.8 } else { 0.9 };
        let new_weight = (h.weight * deload_pct / 5.0).round() * 5.0;
        let new_weight = new_weight.max(default_weight);
        return (
            new_weight,
            format!(
                "Deloading from {} to {} lbs after {} day break.",
                h.weight, new_weight, days_since
            ),
        );
    }

    // 2. Plateau (3 consecutive failures at same weight)
    if history.len() >= 3 {
        let same_weight =
            history[0].weight == history[1].weight && history[1].weight == history[2].weight;
        let all_failed = !history[0].success && !history[1].success && !history[2].success;
        if same_weight && all_failed {
            let new_weight = (h.weight * 0.9 / 5.0).round() * 5.0;
            let new_weight = new_weight.max(default_weight);
            return (
                new_weight,
                format!(
                    "3 failures at {} lbs — deloading to {} lbs to reset.",
                    h.weight, new_weight
                ),
            );
        }
    }

    // 3. Recent failure — hold weight
    if !h.success {
        return (
            h.weight,
            format!(
                "Holding at {} lbs to master the weight after last failure.",
                h.weight
            ),
        );
    }

    // 4. Return to weight mode (recovering from a deload)
    if max_weight > h.weight + increment {
        let successes = history.iter().take_while(|s| s.success).count();
        if successes >= 2 {
            let fast_inc = increment * 2.0;
            let new_weight = h.weight + fast_inc;
            return (
                new_weight,
                format!(
                    "Climbing back to previous max of {} lbs (+{} lbs fast).",
                    max_weight, fast_inc
                ),
            );
        }
    }

    // 5. Standard progression
    let new_weight = h.weight + increment;
    (
        new_weight,
        format!(
            "Progressing from {} to {} lbs after successful session.",
            h.weight, new_weight
        ),
    )
}

// ─── Proposed group builder ───────────────────────────────────────────────────

pub fn build_linear_proposed_groups(statuses: &[ExerciseStatus]) -> Vec<ProposedExerciseGroup> {
    let mut groups = Vec::new();

    let find_status = |ex: Exercise| -> Option<&ExerciseStatus> {
        statuses.iter().find(|s| s.exercise == ex as i32)
    };

    let make_proposal = |status: &ExerciseStatus| -> ExerciseProposal {
        ExerciseProposal {
            weight: status.target_weight,
            sets: status.default_sets,
            reps: status.default_reps,
            explanation: status.explanation.clone(),
        }
    };

    // Squat is always recommended
    if let Some(squat) = find_status(Exercise::Squat) {
        let p = make_proposal(squat);
        groups.push(build_single_group(
            Exercise::Squat,
            &p,
            vec!["recommended".to_string(), "compound".to_string()],
            squat.explanation.clone(),
            rest_cfg(180, 300),
        ));
    }

    // Rotate the 4 main compounds — 2 stalest are recommended
    let mut rotation: Vec<(Exercise, &ExerciseStatus)> = vec![
        Exercise::BenchPress,
        Exercise::Deadlift,
        Exercise::OverheadPress,
        Exercise::BarbellRow,
    ]
    .into_iter()
    .filter_map(|ex| find_status(ex).map(|s| (ex, s)))
    .collect();

    rotation.sort_by(|(a_ex, a), (b_ex, b)| {
        a.last_performed_at
            .cmp(&b.last_performed_at)
            .then((*a_ex as i32).cmp(&(*b_ex as i32)))
    });

    for (idx, (exercise, status)) in rotation.iter().enumerate() {
        let tags = if idx < 2 {
            vec!["recommended".to_string(), "compound".to_string()]
        } else {
            vec!["compound".to_string()]
        };
        let p = make_proposal(status);
        groups.push(build_single_group(
            *exercise,
            &p,
            tags,
            status.explanation.clone(),
            rest_cfg(180, 300),
        ));
    }

    // Auxiliary pairs
    let aux_pairs: &[(Exercise, Exercise)] = &[
        (Exercise::HipThrust, Exercise::BulgarianSplitSquat),
        (Exercise::RomanianDeadlift, Exercise::LegCurl),
        (Exercise::GluteBridge, Exercise::Lunge),
    ];

    for &(ex_a, ex_b) in aux_pairs {
        match (find_status(ex_a), find_status(ex_b)) {
            (Some(a), Some(b)) => {
                let pa = make_proposal(a);
                let pb = make_proposal(b);
                groups.push(ProposedExerciseGroup {
                    name: format!(
                        "{} + {}",
                        exercise_display_name(ex_a),
                        exercise_display_name(ex_b)
                    ),
                    sets: a.default_sets,
                    interleave_warmups: true,
                    exercise_configs: vec![
                        make_exercise_type_config(ex_a, &pa, true),
                        make_exercise_type_config(ex_b, &pb, false),
                    ],
                    rest_config: rest_cfg(90, 90),
                    tags: vec!["auxiliary".to_string()],
                    explanation: format!("{} {}", a.explanation, b.explanation),
                });
            }
            (Some(a), None) => {
                let p = make_proposal(a);
                groups.push(build_single_group(
                    ex_a,
                    &p,
                    vec!["auxiliary".to_string()],
                    a.explanation.clone(),
                    rest_cfg(90, 90),
                ));
            }
            (None, Some(b)) => {
                let p = make_proposal(b);
                groups.push(build_single_group(
                    ex_b,
                    &p,
                    vec!["auxiliary".to_string()],
                    b.explanation.clone(),
                    rest_cfg(90, 90),
                ));
            }
            (None, None) => {}
        }
    }

    groups
}
