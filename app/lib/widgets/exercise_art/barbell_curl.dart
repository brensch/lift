import 'toolkit.dart';

/// Barbell curl — free weight, side view. Elbows pinned, forearms curl up.
ExerciseArt barbellCurlArt() => const ExerciseArt([
  // Arms down.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Curled up to the shoulders.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, -60)], // upper arm pinned, forearm rotates up
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
