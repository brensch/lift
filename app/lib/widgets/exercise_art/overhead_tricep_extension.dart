import 'toolkit.dart';

/// Overhead tricep extension — dumbbell, side view. Standing; upper arm points
/// up (-90°); forearm bends behind head then extends straight up.
ExerciseArt overheadTricepExtensionArt() => const ExerciseArt([
  // Forearm dropped behind head (elbow bent, dumbbell behind).
  Pose(
    figure: Figure(
      pelvis: P(50, 60),
      torso: -90,
      arms: [Limb(-85, 150)], // upper arm up, forearm drops back behind head
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Forearm extended straight up (lockout).
  Pose(
    figure: Figure(
      pelvis: P(50, 60),
      torso: -90,
      arms: [Limb(-85, -90)], // upper arm up, forearm extends up
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
