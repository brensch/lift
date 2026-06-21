import 'toolkit.dart';

/// Dumbbell bench press — dumbbell, side view. Lying flat, dumbbell at chest → press up.
ExerciseArt dumbbellBenchPressArt() => const ExerciseArt([
  // Dumbbell at chest level.
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0, // lying flat
      arms: [Limb(195, -50)],
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)], // bench top
      [P(34, 61), P(34, 82)], // bench leg
      [P(58, 61), P(58, 82)], // bench leg
    ],
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Lockout — arm extended up.
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0,
      arms: [Limb(-88, -90)],
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)],
      [P(34, 61), P(34, 82)],
      [P(58, 61), P(58, 82)],
    ],
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
