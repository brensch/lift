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

/// Maps an [String] to its illustration. One entry per proto name; the file
/// is named after the proto (squat → squat.dart, lat_pulldown → lat_pulldown.dart).
///
/// Exercises without a dedicated drawing fall back to [_genericArt] (a plain
/// standing figure) so the app never breaks while the catalogue is filled in.
final Map<String, ExerciseArt Function()> _artBuilders = {
  'squat': squatArt,
  'bench_press': benchPressArt,
  'leg_press': legPressArt,
  'lat_pulldown': latPulldownArt,
  'hip_thrust': hipThrustArt,
  'deadlift': deadliftArt,
  'overhead_press': overheadPressArt,
  'barbell_row': barbellRowArt,
  'romanian_deadlift': romanianDeadliftArt,
  'lunge': lungeArt,
  'glute_bridge': gluteBridgeArt,
  'leg_curl': legCurlArt,
  'bulgarian_split_squat': bulgarianSplitSquatArt,
  'barbell_curl': barbellCurlArt,
  'front_squat': frontSquatArt,
  'crunch': crunchArt,
  'dumbbell_curl': dumbbellCurlArt,
  'dumbbell_shoulder_press': dumbbellShoulderPressArt,
  'arnold_press': arnoldPressArt,
  'lateral_raise': lateralRaiseArt,
  'front_raise': frontRaiseArt,
  'rear_delt_fly': rearDeltFlyArt,
  'upright_row': uprightRowArt,
  // Chest
  'incline_bench_press': inclineBenchPressArt,
  'dumbbell_bench_press': dumbbellBenchPressArt,
  'incline_dumbbell_press': inclineDumbbellPressArt,
  'dumbbell_fly': dumbbellFlyArt,
  'cable_fly': cableFlyArt,
  'push_up': pushUpArt,
  'chest_dip': chestDipArt,
  'machine_chest_press': machineChestPressArt,
  'pec_deck': pecDeckArt,
  // Arms
  'hammer_curl': hammerCurlArt,
  'preacher_curl': preacherCurlArt,
  'concentration_curl': concentrationCurlArt,
  'cable_curl': cableCurlArt,
  'tricep_pushdown': tricepPushdownArt,
  'overhead_tricep_extension': overheadTricepExtensionArt,
  'skull_crusher': skullCrusherArt,
  'close_grip_bench_press': closeGripBenchPressArt,
  'tricep_dip': tricepDipArt,
  'tricep_kickback': tricepKickbackArt,
  // Back
  'pull_up': pullUpArt,
  'chin_up': chinUpArt,
  'seated_cable_row': seatedCableRowArt,
  'dumbbell_row': dumbbellRowArt,
  't_bar_row': tBarRowArt,
  'pendlay_row': pendlayRowArt,
  'face_pull': facePullArt,
  'shrug': shrugArt,
  'back_extension': backExtensionArt,
  // Legs
  'leg_extension': legExtensionArt,
  'hack_squat': hackSquatArt,
  'goblet_squat': gobletSquatArt,
  'walking_lunge': walkingLungeArt,
  'step_up': stepUpArt,
  'calf_raise': calfRaiseArt,
  'seated_calf_raise': seatedCalfRaiseArt,
  'nordic_curl': nordicCurlArt,
  'good_morning': goodMorningArt,
  // Ass
  'glute_kickback': gluteKickbackArt,
  'sumo_deadlift': sumoDeadliftArt,
  'sumo_squat': sumoSquatArt,
  'curtsy_lunge': curtsyLungeArt,
  'frog_pump': frogPumpArt,
  'single_leg_hip_thrust': singleLegHipThrustArt,
  'cable_pull_through': cablePullThroughArt,
  'hip_abduction': hipAbductionArt,
  'hip_adduction': hipAdductionArt,
  // Core
  'plank': plankArt,
  'hanging_leg_raise': hangingLegRaiseArt,
  'cable_crunch': cableCrunchArt,
  'russian_twist': russianTwistArt,
  'ab_wheel_rollout': abWheelRolloutArt,
  'sit_up': sitUpArt,
  'mountain_climber': mountainClimberArt,
};

/// Returns the art for [exercise] (its key), or the generic fallback figure:
/// a lift a program adds has no drawing.
ExerciseArt artFor(String exercise) =>
    (_artBuilders[exercise] ?? _genericArt)();

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
