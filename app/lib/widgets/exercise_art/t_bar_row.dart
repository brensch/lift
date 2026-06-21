import 'toolkit.dart';

/// T-bar row — free weight, side view. Hinged forward; bar hanging → pulled to chest.
ExerciseArt tBarRowArt() => const ExerciseArt([
  // Bar hanging at arm's length.
  Pose(
    figure: Figure(
      pelvis: P(42, 58),
      torso: -40,
      arms: [Limb(90, 90)],
      legs: [Limb(95, 92), Limb(91, 95)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Bar pulled up to chest.
  Pose(
    figure: Figure(
      pelvis: P(42, 58),
      torso: -40,
      arms: [Limb(145, 35)],
      legs: [Limb(95, 92), Limb(91, 95)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
