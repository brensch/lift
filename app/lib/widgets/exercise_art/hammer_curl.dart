import 'toolkit.dart';

/// Hammer curl — dumbbell, side view. Neutral grip, elbow pinned, forearm curls up.
ExerciseArt hammerCurlArt() => const ExerciseArt([
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
  // Curled up — neutral (hammer) grip looks the same side-on.
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
