import 'toolkit.dart';

/// Concentration curl — dumbbell, side view. Seated, torso hinged forward,
/// arm hangs from elbow-on-thigh, forearm curls up.
ExerciseArt concentrationCurlArt() => const ExerciseArt([
  // Arm hanging straight down.
  Pose(
    figure: Figure(
      pelvis: P(44, 62),
      torso: -60, // leaning forward
      arms: [Limb(90, 90)], // arm hangs straight down from shoulder
      legs: [Limb(10, 95), Limb(13, 98)], // seated, feet on floor
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Forearm curled up.
  Pose(
    figure: Figure(
      pelvis: P(44, 62),
      torso: -60,
      arms: [Limb(90, -30)], // elbow pinned on thigh, forearm curls
      legs: [Limb(10, 95), Limb(13, 98)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
