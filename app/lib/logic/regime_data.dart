import '../gen/workout/v1/settings.pbenum.dart';

/// Descriptor for a training regime (used in onboarding and settings).
class RegimeDef {
  final RegimeType type;
  final String name;
  final String tagline;
  final String description;
  final int defaultDays;
  final List<int> daysOptions;
  final bool needsOneRepMaxes;

  const RegimeDef({
    required this.type,
    required this.name,
    required this.tagline,
    required this.description,
    required this.defaultDays,
    required this.daysOptions,
    required this.needsOneRepMaxes,
  });
}

const regimeDefs = [
  RegimeDef(
    type: RegimeType.REGIME_TYPE_LINEAR_5X5,
    name: 'Linear 5×5',
    tagline: 'Best for beginners.',
    description:
        'Add weight every session. 5 sets of 5 reps on the big lifts. When you stall, deload 10% and rebuild.',
    defaultDays: 3,
    daysOptions: [3],
    needsOneRepMaxes: false,
  ),
  RegimeDef(
    type: RegimeType.REGIME_TYPE_GZCLP,
    name: 'GZCLP',
    tagline: 'Tiered state machine progression.',
    description:
        'Exercises ranked T1/T2/T3 by intensity. Each tier has a state machine — fail a stage and the rep scheme shifts to preserve intensity through a different pathway.',
    defaultDays: 4,
    daysOptions: [3, 4, 5],
    needsOneRepMaxes: false,
  ),
  RegimeDef(
    type: RegimeType.REGIME_TYPE_WENDLER_531,
    name: 'Wendler 5/3/1',
    tagline: 'Percentage waves off your Training Max.',
    description:
        '4-week cycles: Volume → Intensity → Peak → Deload. You work off 90% of your 1RM. After each cycle, your Training Max increases. Slow and sustainable.',
    defaultDays: 4,
    daysOptions: [4],
    needsOneRepMaxes: true,
  ),
];

/// Descriptor for an exercise entry in the weight configuration UI.
class ExerciseDef {
  final String name;
  final int exerciseInt; // Exercise proto enum int
  final double defaultWeight; // lbs
  final bool isWendlerMain;

  const ExerciseDef({
    required this.name,
    required this.exerciseInt,
    required this.defaultWeight,
    required this.isWendlerMain,
  });
}

const exerciseDefs = [
  ExerciseDef(name: 'Squat', exerciseInt: 1, defaultWeight: 135, isWendlerMain: true),
  ExerciseDef(name: 'Bench Press', exerciseInt: 2, defaultWeight: 95, isWendlerMain: true),
  ExerciseDef(name: 'Deadlift', exerciseInt: 3, defaultWeight: 185, isWendlerMain: true),
  ExerciseDef(name: 'Overhead Press', exerciseInt: 4, defaultWeight: 65, isWendlerMain: true),
  ExerciseDef(name: 'Barbell Row', exerciseInt: 5, defaultWeight: 95, isWendlerMain: false),
];
