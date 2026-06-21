import '../../gen/workout/v1/workout.pbenum.dart';
import 'toolkit.dart';

import 'barbell_curl.dart';
import 'barbell_row.dart';
import 'bench_press.dart';
import 'bulgarian_split_squat.dart';
import 'arnold_press.dart';
import 'crunch.dart';
import 'deadlift.dart';
import 'dumbbell_curl.dart';
import 'dumbbell_shoulder_press.dart';
import 'front_raise.dart';
import 'front_squat.dart';
import 'lateral_raise.dart';
import 'rear_delt_fly.dart';
import 'upright_row.dart';
import 'glute_bridge.dart';
import 'hip_thrust.dart';
import 'lat_pulldown.dart';
import 'leg_curl.dart';
import 'leg_press.dart';
import 'lunge.dart';
import 'overhead_press.dart';
import 'romanian_deadlift.dart';
import 'squat.dart';
// Chest
import 'incline_bench_press.dart';
import 'dumbbell_bench_press.dart';
import 'incline_dumbbell_press.dart';
import 'dumbbell_fly.dart';
import 'cable_fly.dart';
import 'push_up.dart';
import 'chest_dip.dart';
import 'machine_chest_press.dart';
import 'pec_deck.dart';
// Arms
import 'hammer_curl.dart';
import 'preacher_curl.dart';
import 'concentration_curl.dart';
import 'cable_curl.dart';
import 'tricep_pushdown.dart';
import 'overhead_tricep_extension.dart';
import 'skull_crusher.dart';
import 'close_grip_bench_press.dart';
import 'tricep_dip.dart';
import 'tricep_kickback.dart';
// Back
import 'pull_up.dart';
import 'chin_up.dart';
import 'seated_cable_row.dart';
import 'dumbbell_row.dart';
import 't_bar_row.dart';
import 'pendlay_row.dart';
import 'face_pull.dart';
import 'shrug.dart';
import 'back_extension.dart';
// Legs
import 'leg_extension.dart';
import 'hack_squat.dart';
import 'goblet_squat.dart';
import 'walking_lunge.dart';
import 'step_up.dart';
import 'calf_raise.dart';
import 'seated_calf_raise.dart';
import 'nordic_curl.dart';
import 'good_morning.dart';
// Ass
import 'glute_kickback.dart';
import 'sumo_deadlift.dart';
import 'sumo_squat.dart';
import 'curtsy_lunge.dart';
import 'frog_pump.dart';
import 'single_leg_hip_thrust.dart';
import 'cable_pull_through.dart';
import 'hip_abduction.dart';
import 'hip_adduction.dart';
// Core
import 'plank.dart';
import 'hanging_leg_raise.dart';
import 'cable_crunch.dart';
import 'russian_twist.dart';
import 'ab_wheel_rollout.dart';
import 'sit_up.dart';
import 'mountain_climber.dart';

/// Maps an [Exercise] to its illustration. One entry per proto name; the file
/// is named after the proto (squat → squat.dart, lat_pulldown → lat_pulldown.dart).
///
/// Exercises without a dedicated drawing fall back to [_genericArt] (a plain
/// standing figure) so the app never breaks while the catalogue is filled in.
final Map<Exercise, ExerciseArt Function()> _artBuilders = {
  Exercise.EXERCISE_SQUAT: squatArt,
  Exercise.EXERCISE_BENCH_PRESS: benchPressArt,
  Exercise.EXERCISE_LEG_PRESS: legPressArt,
  Exercise.EXERCISE_LAT_PULLDOWN: latPulldownArt,
  Exercise.EXERCISE_HIP_THRUST: hipThrustArt,
  Exercise.EXERCISE_DEADLIFT: deadliftArt,
  Exercise.EXERCISE_OVERHEAD_PRESS: overheadPressArt,
  Exercise.EXERCISE_BARBELL_ROW: barbellRowArt,
  Exercise.EXERCISE_ROMANIAN_DEADLIFT: romanianDeadliftArt,
  Exercise.EXERCISE_LUNGE: lungeArt,
  Exercise.EXERCISE_GLUTE_BRIDGE: gluteBridgeArt,
  Exercise.EXERCISE_LEG_CURL: legCurlArt,
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT: bulgarianSplitSquatArt,
  Exercise.EXERCISE_BARBELL_CURL: barbellCurlArt,
  Exercise.EXERCISE_FRONT_SQUAT: frontSquatArt,
  Exercise.EXERCISE_CRUNCH: crunchArt,
  Exercise.EXERCISE_DUMBBELL_CURL: dumbbellCurlArt,
  Exercise.EXERCISE_DUMBBELL_SHOULDER_PRESS: dumbbellShoulderPressArt,
  Exercise.EXERCISE_ARNOLD_PRESS: arnoldPressArt,
  Exercise.EXERCISE_LATERAL_RAISE: lateralRaiseArt,
  Exercise.EXERCISE_FRONT_RAISE: frontRaiseArt,
  Exercise.EXERCISE_REAR_DELT_FLY: rearDeltFlyArt,
  Exercise.EXERCISE_UPRIGHT_ROW: uprightRowArt,
  // Chest
  Exercise.EXERCISE_INCLINE_BENCH_PRESS: inclineBenchPressArt,
  Exercise.EXERCISE_DUMBBELL_BENCH_PRESS: dumbbellBenchPressArt,
  Exercise.EXERCISE_INCLINE_DUMBBELL_PRESS: inclineDumbbellPressArt,
  Exercise.EXERCISE_DUMBBELL_FLY: dumbbellFlyArt,
  Exercise.EXERCISE_CABLE_FLY: cableFlyArt,
  Exercise.EXERCISE_PUSH_UP: pushUpArt,
  Exercise.EXERCISE_CHEST_DIP: chestDipArt,
  Exercise.EXERCISE_MACHINE_CHEST_PRESS: machineChestPressArt,
  Exercise.EXERCISE_PEC_DECK: pecDeckArt,
  // Arms
  Exercise.EXERCISE_HAMMER_CURL: hammerCurlArt,
  Exercise.EXERCISE_PREACHER_CURL: preacherCurlArt,
  Exercise.EXERCISE_CONCENTRATION_CURL: concentrationCurlArt,
  Exercise.EXERCISE_CABLE_CURL: cableCurlArt,
  Exercise.EXERCISE_TRICEP_PUSHDOWN: tricepPushdownArt,
  Exercise.EXERCISE_OVERHEAD_TRICEP_EXTENSION: overheadTricepExtensionArt,
  Exercise.EXERCISE_SKULL_CRUSHER: skullCrusherArt,
  Exercise.EXERCISE_CLOSE_GRIP_BENCH_PRESS: closeGripBenchPressArt,
  Exercise.EXERCISE_TRICEP_DIP: tricepDipArt,
  Exercise.EXERCISE_TRICEP_KICKBACK: tricepKickbackArt,
  // Back
  Exercise.EXERCISE_PULL_UP: pullUpArt,
  Exercise.EXERCISE_CHIN_UP: chinUpArt,
  Exercise.EXERCISE_SEATED_CABLE_ROW: seatedCableRowArt,
  Exercise.EXERCISE_DUMBBELL_ROW: dumbbellRowArt,
  Exercise.EXERCISE_T_BAR_ROW: tBarRowArt,
  Exercise.EXERCISE_PENDLAY_ROW: pendlayRowArt,
  Exercise.EXERCISE_FACE_PULL: facePullArt,
  Exercise.EXERCISE_SHRUG: shrugArt,
  Exercise.EXERCISE_BACK_EXTENSION: backExtensionArt,
  // Legs
  Exercise.EXERCISE_LEG_EXTENSION: legExtensionArt,
  Exercise.EXERCISE_HACK_SQUAT: hackSquatArt,
  Exercise.EXERCISE_GOBLET_SQUAT: gobletSquatArt,
  Exercise.EXERCISE_WALKING_LUNGE: walkingLungeArt,
  Exercise.EXERCISE_STEP_UP: stepUpArt,
  Exercise.EXERCISE_CALF_RAISE: calfRaiseArt,
  Exercise.EXERCISE_SEATED_CALF_RAISE: seatedCalfRaiseArt,
  Exercise.EXERCISE_NORDIC_CURL: nordicCurlArt,
  Exercise.EXERCISE_GOOD_MORNING: goodMorningArt,
  // Ass
  Exercise.EXERCISE_GLUTE_KICKBACK: gluteKickbackArt,
  Exercise.EXERCISE_SUMO_DEADLIFT: sumoDeadliftArt,
  Exercise.EXERCISE_SUMO_SQUAT: sumoSquatArt,
  Exercise.EXERCISE_CURTSY_LUNGE: curtsyLungeArt,
  Exercise.EXERCISE_FROG_PUMP: frogPumpArt,
  Exercise.EXERCISE_SINGLE_LEG_HIP_THRUST: singleLegHipThrustArt,
  Exercise.EXERCISE_CABLE_PULL_THROUGH: cablePullThroughArt,
  Exercise.EXERCISE_HIP_ABDUCTION: hipAbductionArt,
  Exercise.EXERCISE_HIP_ADDUCTION: hipAdductionArt,
  // Core
  Exercise.EXERCISE_PLANK: plankArt,
  Exercise.EXERCISE_HANGING_LEG_RAISE: hangingLegRaiseArt,
  Exercise.EXERCISE_CABLE_CRUNCH: cableCrunchArt,
  Exercise.EXERCISE_RUSSIAN_TWIST: russianTwistArt,
  Exercise.EXERCISE_AB_WHEEL_ROLLOUT: abWheelRolloutArt,
  Exercise.EXERCISE_SIT_UP: sitUpArt,
  Exercise.EXERCISE_MOUNTAIN_CLIMBER: mountainClimberArt,
};

/// Returns the art for [exercise], or the generic fallback figure.
ExerciseArt artFor(Exercise exercise) =>
    (_artBuilders[exercise] ?? _genericArt)();

/// True if a hand-drawn illustration exists (vs. the generic fallback).
bool hasExerciseArt(Exercise exercise) => _artBuilders.containsKey(exercise);

/// Plain standing figure used until an exercise has its own drawing.
ExerciseArt _genericArt() => const ExerciseArt([
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(95, 95), Limb(85, 85)],
      legs: [Limb(93, 93), Limb(87, 87)],
    ),
  ),
]);
