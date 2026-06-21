import 'toolkit.dart';

/// Deadlift — free weight, side view. Bar low off the floor (knees bent, hips
/// down) → lockout. Distinct from the RDL: more knee bend, bar lower.
ExerciseArt deadliftArt() => const ExerciseArt([
  // Bottom — hips down, knees bent, bar at the shins.
  Pose(
    figure: Figure(
      pelvis: P(42, 66),
      torso: -58,
      arms: [Limb(90, 90)], // hanging straight to the bar
      legs: [Limb(38, 115), Limb(35, 118)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Lockout.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
