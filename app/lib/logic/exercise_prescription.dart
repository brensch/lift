/// The catalog the app prescribes from, and the calibration-ramp maths that
/// reads it. A mirror of `load_style`, `category`, `prescription`,
/// `starting_weight_lb`, `progression_increment_lb` and `snap_weight_lb` in
/// core/src/exercise_catalog.rs, the plate snapping in core/src/weight_units.rs,
/// `calibration_start_weight` in core/src/exercise_progress.rs and the
/// calibration helpers in core/src/workout/planning.rs. The optimistic reducer in
/// WorkoutProvider appends ramp rungs and working sets with these, and the
/// server must land on the same numbers or the plan flickers.
///
/// Weights are stored in pounds and the server does its arithmetic in f32,
/// so every intermediate here is rounded to f32 as well: a .5 boundary that
/// rounds one way in f32 and the other in f64 is a real, previously seen
/// mismatch.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'weight_units.dart';

/// How a move is loaded; decides the smallest step, the opener and whether
/// adding weight is even the right progression.
enum LoadStyle { barbell, dumbbell, machine, cable, bodyweight }

const Set<Exercise> _barbell = {
  Exercise.EXERCISE_SQUAT,
  Exercise.EXERCISE_BENCH_PRESS,
  Exercise.EXERCISE_DEADLIFT,
  Exercise.EXERCISE_OVERHEAD_PRESS,
  Exercise.EXERCISE_BARBELL_ROW,
  Exercise.EXERCISE_HIP_THRUST,
  Exercise.EXERCISE_ROMANIAN_DEADLIFT,
  Exercise.EXERCISE_GLUTE_BRIDGE,
  Exercise.EXERCISE_INCLINE_BENCH_PRESS,
  Exercise.EXERCISE_PENDLAY_ROW,
  Exercise.EXERCISE_T_BAR_ROW,
  Exercise.EXERCISE_SHRUG,
  Exercise.EXERCISE_UPRIGHT_ROW,
  Exercise.EXERCISE_BARBELL_CURL,
  Exercise.EXERCISE_PREACHER_CURL,
  Exercise.EXERCISE_SKULL_CRUSHER,
  Exercise.EXERCISE_CLOSE_GRIP_BENCH_PRESS,
  Exercise.EXERCISE_FRONT_SQUAT,
  Exercise.EXERCISE_GOOD_MORNING,
  Exercise.EXERCISE_SUMO_DEADLIFT,
};

const Set<Exercise> _dumbbell = {
  Exercise.EXERCISE_DUMBBELL_BENCH_PRESS,
  Exercise.EXERCISE_INCLINE_DUMBBELL_PRESS,
  Exercise.EXERCISE_DUMBBELL_FLY,
  Exercise.EXERCISE_DUMBBELL_ROW,
  Exercise.EXERCISE_DUMBBELL_SHOULDER_PRESS,
  Exercise.EXERCISE_ARNOLD_PRESS,
  Exercise.EXERCISE_LATERAL_RAISE,
  Exercise.EXERCISE_FRONT_RAISE,
  Exercise.EXERCISE_REAR_DELT_FLY,
  Exercise.EXERCISE_DUMBBELL_CURL,
  Exercise.EXERCISE_HAMMER_CURL,
  Exercise.EXERCISE_CONCENTRATION_CURL,
  Exercise.EXERCISE_OVERHEAD_TRICEP_EXTENSION,
  Exercise.EXERCISE_TRICEP_KICKBACK,
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT,
  Exercise.EXERCISE_LUNGE,
  Exercise.EXERCISE_WALKING_LUNGE,
  Exercise.EXERCISE_STEP_UP,
  Exercise.EXERCISE_GOBLET_SQUAT,
  Exercise.EXERCISE_CURTSY_LUNGE,
  Exercise.EXERCISE_SUMO_SQUAT,
  Exercise.EXERCISE_CALF_RAISE,
  Exercise.EXERCISE_RUSSIAN_TWIST,
};

const Set<Exercise> _machine = {
  Exercise.EXERCISE_MACHINE_CHEST_PRESS,
  Exercise.EXERCISE_PEC_DECK,
  Exercise.EXERCISE_LEG_PRESS,
  Exercise.EXERCISE_LEG_EXTENSION,
  Exercise.EXERCISE_LEG_CURL,
  Exercise.EXERCISE_HACK_SQUAT,
  Exercise.EXERCISE_SEATED_CALF_RAISE,
  Exercise.EXERCISE_HIP_ABDUCTION,
  Exercise.EXERCISE_HIP_ADDUCTION,
};

const Set<Exercise> _cable = {
  Exercise.EXERCISE_CABLE_FLY,
  Exercise.EXERCISE_LAT_PULLDOWN,
  Exercise.EXERCISE_SEATED_CABLE_ROW,
  Exercise.EXERCISE_FACE_PULL,
  Exercise.EXERCISE_CABLE_CURL,
  Exercise.EXERCISE_TRICEP_PUSHDOWN,
  Exercise.EXERCISE_CABLE_PULL_THROUGH,
  Exercise.EXERCISE_CABLE_CRUNCH,
  Exercise.EXERCISE_GLUTE_KICKBACK,
};

/// Listed (rather than "everything else") so a test can check the five
/// classes partition the catalogue, as the exhaustive Rust match does.
const Set<Exercise> bodyweightExercises = {
  Exercise.EXERCISE_PUSH_UP,
  Exercise.EXERCISE_CHEST_DIP,
  Exercise.EXERCISE_TRICEP_DIP,
  Exercise.EXERCISE_PULL_UP,
  Exercise.EXERCISE_CHIN_UP,
  Exercise.EXERCISE_BACK_EXTENSION,
  Exercise.EXERCISE_NORDIC_CURL,
  Exercise.EXERCISE_FROG_PUMP,
  Exercise.EXERCISE_SINGLE_LEG_HIP_THRUST,
  Exercise.EXERCISE_PLANK,
  Exercise.EXERCISE_HANGING_LEG_RAISE,
  Exercise.EXERCISE_AB_WHEEL_ROLLOUT,
  Exercise.EXERCISE_SIT_UP,
  Exercise.EXERCISE_CRUNCH,
  Exercise.EXERCISE_MOUNTAIN_CLIMBER,
};

/// Every exercise the classification knows, for the partition test.
Set<Exercise> get classifiedExercises => {
  ..._barbell,
  ..._dumbbell,
  ..._machine,
  ..._cable,
  ...bodyweightExercises,
};

LoadStyle loadStyleOf(Exercise exercise) {
  if (_barbell.contains(exercise)) return LoadStyle.barbell;
  if (_dumbbell.contains(exercise)) return LoadStyle.dumbbell;
  if (_machine.contains(exercise)) return LoadStyle.machine;
  if (_cable.contains(exercise)) return LoadStyle.cable;
  return LoadStyle.bodyweight;
}

const Set<Exercise> _compound = {
  Exercise.EXERCISE_SQUAT,
  Exercise.EXERCISE_BENCH_PRESS,
  Exercise.EXERCISE_DEADLIFT,
  Exercise.EXERCISE_OVERHEAD_PRESS,
  Exercise.EXERCISE_BARBELL_ROW,
  Exercise.EXERCISE_HIP_THRUST,
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT,
  Exercise.EXERCISE_ROMANIAN_DEADLIFT,
  Exercise.EXERCISE_GLUTE_BRIDGE,
  Exercise.EXERCISE_LUNGE,
  Exercise.EXERCISE_INCLINE_BENCH_PRESS,
  Exercise.EXERCISE_DUMBBELL_BENCH_PRESS,
  Exercise.EXERCISE_INCLINE_DUMBBELL_PRESS,
  Exercise.EXERCISE_PUSH_UP,
  Exercise.EXERCISE_CHEST_DIP,
  Exercise.EXERCISE_MACHINE_CHEST_PRESS,
  Exercise.EXERCISE_PULL_UP,
  Exercise.EXERCISE_CHIN_UP,
  Exercise.EXERCISE_LAT_PULLDOWN,
  Exercise.EXERCISE_SEATED_CABLE_ROW,
  Exercise.EXERCISE_DUMBBELL_ROW,
  Exercise.EXERCISE_T_BAR_ROW,
  Exercise.EXERCISE_PENDLAY_ROW,
  Exercise.EXERCISE_DUMBBELL_SHOULDER_PRESS,
  Exercise.EXERCISE_ARNOLD_PRESS,
  Exercise.EXERCISE_CLOSE_GRIP_BENCH_PRESS,
  Exercise.EXERCISE_TRICEP_DIP,
  Exercise.EXERCISE_FRONT_SQUAT,
  Exercise.EXERCISE_LEG_PRESS,
  Exercise.EXERCISE_HACK_SQUAT,
  Exercise.EXERCISE_GOBLET_SQUAT,
  Exercise.EXERCISE_WALKING_LUNGE,
  Exercise.EXERCISE_STEP_UP,
  Exercise.EXERCISE_GOOD_MORNING,
  Exercise.EXERCISE_SUMO_DEADLIFT,
  Exercise.EXERCISE_SUMO_SQUAT,
  Exercise.EXERCISE_CURTSY_LUNGE,
  Exercise.EXERCISE_SINGLE_LEG_HIP_THRUST,
  Exercise.EXERCISE_CABLE_PULL_THROUGH,
};

bool isCompound(Exercise exercise) => _compound.contains(exercise);

/// Primary mover is the core (`primary_muscle(ex) == Core`).
const Set<Exercise> _corePrimary = {
  Exercise.EXERCISE_PLANK,
  Exercise.EXERCISE_HANGING_LEG_RAISE,
  Exercise.EXERCISE_CABLE_CRUNCH,
  Exercise.EXERCISE_RUSSIAN_TWIST,
  Exercise.EXERCISE_AB_WHEEL_ROLLOUT,
  Exercise.EXERCISE_SIT_UP,
  Exercise.EXERCISE_CRUNCH,
  Exercise.EXERCISE_MOUNTAIN_CLIMBER,
};

/// Any of quads, hamstrings or glutes among the move's muscles.
const Set<Exercise> _loadsLowerBody = {
  Exercise.EXERCISE_SQUAT,
  Exercise.EXERCISE_DEADLIFT,
  Exercise.EXERCISE_HIP_THRUST,
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT,
  Exercise.EXERCISE_ROMANIAN_DEADLIFT,
  Exercise.EXERCISE_GLUTE_BRIDGE,
  Exercise.EXERCISE_LUNGE,
  Exercise.EXERCISE_LEG_CURL,
  Exercise.EXERCISE_BACK_EXTENSION,
  Exercise.EXERCISE_FRONT_SQUAT,
  Exercise.EXERCISE_LEG_PRESS,
  Exercise.EXERCISE_LEG_EXTENSION,
  Exercise.EXERCISE_HACK_SQUAT,
  Exercise.EXERCISE_GOBLET_SQUAT,
  Exercise.EXERCISE_WALKING_LUNGE,
  Exercise.EXERCISE_STEP_UP,
  Exercise.EXERCISE_NORDIC_CURL,
  Exercise.EXERCISE_GOOD_MORNING,
  Exercise.EXERCISE_GLUTE_KICKBACK,
  Exercise.EXERCISE_SUMO_DEADLIFT,
  Exercise.EXERCISE_SUMO_SQUAT,
  Exercise.EXERCISE_CURTSY_LUNGE,
  Exercise.EXERCISE_FROG_PUMP,
  Exercise.EXERCISE_SINGLE_LEG_HIP_THRUST,
  Exercise.EXERCISE_CABLE_PULL_THROUGH,
  Exercise.EXERCISE_HIP_ABDUCTION,
  Exercise.EXERCISE_HIP_ADDUCTION,
};

/// What the catalog prescribes for an exercise: sets, rep range, rest.
class Prescription {
  final int sets;
  final int repLow;
  final int repHigh;
  final int restSeconds;
  final int restSecondsFailure;
  final bool includeWarmup;

  const Prescription({
    required this.sets,
    required this.repLow,
    required this.repHigh,
    required this.restSeconds,
    required this.restSecondsFailure,
    required this.includeWarmup,
  });
}

/// Mirrors `prescription` in core/src/exercise_catalog.rs.
Prescription prescriptionFor(Exercise exercise) {
  if (_corePrimary.contains(exercise)) {
    return const Prescription(
      sets: 3,
      repLow: 10,
      repHigh: 20,
      restSeconds: 60,
      restSecondsFailure: 90,
      includeWarmup: false,
    );
  }
  final style = loadStyleOf(exercise);
  final compound = isCompound(exercise);
  if (style == LoadStyle.barbell && compound) {
    final lower = _loadsLowerBody.contains(exercise);
    return Prescription(
      sets: 3,
      repLow: 6,
      repHigh: 10,
      restSeconds: lower ? 180 : 150,
      restSecondsFailure: lower ? 240 : 210,
      includeWarmup: true,
    );
  }
  if (style == LoadStyle.bodyweight && compound) {
    return const Prescription(
      sets: 3,
      repLow: 5,
      repHigh: 15,
      restSeconds: 120,
      restSecondsFailure: 180,
      includeWarmup: false,
    );
  }
  if (compound) {
    return const Prescription(
      sets: 3,
      repLow: 8,
      repHigh: 12,
      restSeconds: 120,
      restSecondsFailure: 180,
      includeWarmup: false,
    );
  }
  return const Prescription(
    sets: 3,
    repLow: 10,
    repHigh: 15,
    restSeconds: 90,
    restSecondsFailure: 120,
    includeWarmup: false,
  );
}

// ─── f32 arithmetic ──────────────────────────────────────────────────────

final Float32List _f32Scratch = Float32List(1);

/// [x] rounded to the nearest single-precision float. Rounding the exact
/// double result of one +, −, × or ÷ to f32 gives exactly what f32
/// arithmetic gives, so wrapping every operation reproduces the server.
double f32(double x) {
  _f32Scratch[0] = x;
  return _f32Scratch[0];
}

final double _lbToKg = f32(0.45359237);

double _poundsToKg(double lb) => f32(lb * _lbToKg);
double _kgToPounds(double kg) => f32(kg / _lbToKg);

double _roundToUnitIncrement(
  double weightLb,
  WeightUnit unit,
  double lbStep,
  double kgStep,
) {
  if (isMetricUnit(unit)) {
    final kg = f32(_poundsToKg(weightLb) / kgStep).roundToDouble();
    return _kgToPounds(f32(kg * kgStep));
  }
  return f32(f32(weightLb / lbStep).roundToDouble() * lbStep);
}

/// Mirrors `snap_loadable` in core/src/weight_units.rs: the nearest weight that
/// is exactly loadable on the bar; below the bar, the smallest plate's grid.
double _snapLoadable(double target, double bar, List<double> plates) {
  final smallest = plates.last;
  if (target < bar) {
    final onGrid = f32(f32(target / smallest).roundToDouble() * smallest);
    return math.max(onGrid, 0.0);
  }
  final step = f32(smallest * 2);
  final steps = f32(f32(target - bar) / step).roundToDouble();
  return f32(bar + f32(steps * step));
}

double _snapLoadableLb(double weightLb, WeightUnit unit) {
  final display = isMetricUnit(unit) ? _poundsToKg(weightLb) : weightLb;
  final snapped = _snapLoadable(
    display,
    standardBarWeight(unit),
    standardPlates(unit),
  );
  return isMetricUnit(unit) ? _kgToPounds(snapped) : snapped;
}

/// Mirrors `snap_weight_lb`: a computed weight rounded to what the
/// equipment can actually load.
double snapWeightLb(Exercise exercise, double weightLb, WeightUnit unit) {
  if (weightLb <= 0) return 0;
  switch (loadStyleOf(exercise)) {
    case LoadStyle.barbell:
      return _snapLoadableLb(weightLb, unit);
    case LoadStyle.bodyweight:
      return weightLb;
    case LoadStyle.dumbbell:
      return _roundToUnitIncrement(weightLb, unit, 5, 2);
    case LoadStyle.machine:
    case LoadStyle.cable:
      return _roundToUnitIncrement(weightLb, unit, 5, 2.5);
  }
}

double _inUnit(WeightUnit unit, double lb, double kg) =>
    isMetricUnit(unit) ? _kgToPounds(kg) : lb;

/// Mirrors `progression_increment_lb`: one equipment step, 0 for bodyweight.
double progressionIncrementLb(Exercise exercise, WeightUnit unit) {
  switch (loadStyleOf(exercise)) {
    case LoadStyle.bodyweight:
      return 0;
    case LoadStyle.dumbbell:
      return _inUnit(unit, 5, 2);
    case LoadStyle.barbell:
    case LoadStyle.machine:
    case LoadStyle.cable:
      return _inUnit(unit, 5, 2.5);
  }
}

/// Mirrors `starting_weight_lb`: the opener for an exercise with no history.
double startingWeightLb(Exercise exercise, WeightUnit unit) {
  switch (loadStyleOf(exercise)) {
    case LoadStyle.barbell:
      return _inUnit(unit, 45, 20);
    case LoadStyle.dumbbell:
      return _inUnit(unit, 20, 10);
    case LoadStyle.machine:
      return _inUnit(unit, 40, 20);
    case LoadStyle.cable:
      return _inUnit(unit, 20, 10);
    case LoadStyle.bodyweight:
      return 0;
  }
}

// ─── Calibration ─────────────────────────────────────────────────────────

/// The id of the [n]th set a calibration answer appends: uuid v5 over the
/// OID namespace of "{completedSetId}:{n}", where [completedSetId] is the
/// done rung being rated. Both reducers mint the same id, so a Done tapped
/// on an optimistic rung before the server replies lands on the real row.
String appendedSetId(String completedSetId, int n) =>
    const Uuid().v5(Namespace.oid.value, '$completedSetId:$n');

/// A calibration rung is always five reps, rested 90 s whatever happened.
const int calibrationReps = 5;
const int calibrationRestSeconds = 90;

/// The ramp stops here; the sixth rung is treated as right.
const int maxCalibrationRungs = 6;

final double _calibrationRungFraction = f32(1.10);
final double _calibrationSeedFraction = f32(0.6);

/// Mirrors `calibration_start_weight`: where a ramp starts, or null when the
/// exercise does not calibrate (bodyweight, or performed before). With a
/// seed the ramp opens at 60% of it, snapped, never under the opener.
///
/// [seedWeightLb] is the tracker's working weight. The server reads the
/// stored state (0 when never set) where the app only sees the resolved
/// tracker (the opener when never set); both land on the opener because
/// 60% of the opener can never exceed it.
double? calibrationStartWeight(
  Exercise exercise, {
  required double seedWeightLb,
  required bool performedBefore,
  required WeightUnit unit,
}) {
  if (progressionIncrementLb(exercise, unit) <= 0) return null;
  if (performedBefore) return null;
  final opener = startingWeightLb(exercise, unit);
  if (seedWeightLb > 0) {
    final start = snapWeightLb(
      exercise,
      f32(seedWeightLb * _calibrationSeedFraction),
      unit,
    );
    return math.max(start, opener);
  }
  return opener;
}

/// Mirrors `next_calibration_weight`: the next rung up, the larger of one
/// equipment step and 10%, snapped to what the exercise can load.
double nextCalibrationWeight(
  Exercise exercise,
  double weightLb,
  WeightUnit unit,
) {
  final step = progressionIncrementLb(exercise, unit);
  final byStep = f32(weightLb + step);
  final byFraction = f32(weightLb * _calibrationRungFraction);
  return snapWeightLb(exercise, math.max(byStep, byFraction), unit);
}

/// Mirrors `calibration_set`: one rung of the ramp at [weightLb].
ProposedSet calibrationSet({
  required String id,
  required String workoutId,
  required Exercise exercise,
  required double weightLb,
}) => ProposedSet()
  ..id = id
  ..workoutId = workoutId
  ..workoutOrder = 0
  ..exercise = exercise
  ..targetReps = calibrationReps
  ..targetWeight = weightLb
  ..warmup = false
  ..restAfterSuccess = calibrationRestSeconds
  ..restAfterFailure = calibrationRestSeconds
  ..cancelled = false
  ..calibration = true;

/// Mirrors `working_sets_after_calibration`: the prescription's sets minus
/// one (the rung that found the weight counts), at its range bottom and
/// rest, all at [weightLb]. [newId] mints one id per set.
List<ProposedSet> workingSetsAfterCalibration({
  required String workoutId,
  required Exercise exercise,
  required double weightLb,
  required String Function() newId,
}) {
  final p = prescriptionFor(exercise);
  final count = math.max(p.sets - 1, 1);
  return [
    for (var i = 0; i < count; i++)
      ProposedSet()
        ..id = newId()
        ..workoutId = workoutId
        ..workoutOrder = 0
        ..exercise = exercise
        ..targetReps = p.repLow
        ..targetWeight = weightLb
        ..warmup = false
        ..restAfterSuccess = p.restSeconds
        ..restAfterFailure = p.restSecondsFailure
        ..cancelled = false
        ..calibration = false,
  ];
}
