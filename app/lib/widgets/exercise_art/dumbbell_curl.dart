import 'toolkit.dart';

/// Dumbbell curl — free weight, side view. Elbow pinned, forearm curls up.
ExerciseArt dumbbellCurlArt() => const ExerciseArt([
  // Arm down.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Curled up.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, -60)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
