import 'toolkit.dart';

/// Barbell row — free weight, side view. Bar hanging → pulled to the torso.
ExerciseArt barbellRowArt() => const ExerciseArt([
  // Bar hanging at arm's length.
  Pose(
    figure: Figure(
      pelvis: P(40, 56),
      torso: -35,
      arms: [Limb(90, 90)],
      legs: [Limb(95, 92), Limb(91, 95)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Bar pulled to the torso.
  Pose(
    figure: Figure(
      pelvis: P(40, 56),
      torso: -35,
      arms: [Limb(150, 40)],
      legs: [Limb(95, 92), Limb(91, 95)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
