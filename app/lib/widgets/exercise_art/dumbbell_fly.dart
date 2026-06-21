import 'toolkit.dart';

/// Dumbbell fly — dumbbell, side view. Lying flat; arm sweeps wide then closes over chest.
ExerciseArt dumbbellFlyArt() => const ExerciseArt([
  // Arm opened out wide to the side (stretched/loaded position).
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0, // lying flat
      arms: [Limb(-5, -10)], // arm nearly horizontal, extended away from body (wide open)
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)], // bench top
      [P(34, 61), P(34, 82)], // bench leg
      [P(58, 61), P(58, 82)], // bench leg
    ],
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Arm closed — dumbbell over chest.
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0,
      arms: [Limb(-88, -90)], // arm extended straight up over chest
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
