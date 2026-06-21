import 'toolkit.dart';

/// Front raise — dumbbell, side view. Arm raises forward from thigh to horizontal.
ExerciseArt frontRaiseArt() => const ExerciseArt([
  // Start — arm hanging straight down at the thigh.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90), Limb(91, 91)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Top — arm raised forward to horizontal (0 = right = forward in side view).
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(0, 0), Limb(91, 91)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
