import 'toolkit.dart';

/// Close-grip bench press — barbell, side view. Lying on flat bench; like
/// bench press but narrower grip; tricep-focused press.
ExerciseArt closeGripBenchPressArt() => const ExerciseArt([
  // Bar at chest (lowered).
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0, // lying flat, head to the right
      arms: [Limb(195, -50)], // elbow tucked closer to body than bench press
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)], // bench top
      [P(34, 61), P(34, 82)], // bench leg
      [P(58, 61), P(58, 82)], // bench leg
    ],
    barbells: [Barbell(hands: [0])],
  ),
  // Lockout.
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0,
      arms: [Limb(-88, -90)], // arms extended straight up
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)],
      [P(34, 61), P(34, 82)],
      [P(58, 61), P(58, 82)],
    ],
    barbells: [Barbell(hands: [0])],
  ),
]);
