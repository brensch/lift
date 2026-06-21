import 'toolkit.dart';

/// Dumbbell row — free weight, side view. Hinged forward; arm hangs → rows dumbbell to ribs.
ExerciseArt dumbbellRowArt() => const ExerciseArt([
  // Arm hanging down, dumbbell at its lowest.
  Pose(
    figure: Figure(
      pelvis: P(40, 58),
      torso: -35,
      arms: [Limb(90, 90)],
      legs: [Limb(95, 92), Limb(91, 95)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
    props: [
      [P(56, 62), P(80, 62)], // bench top
      [P(60, 62), P(60, 82)], // bench leg
      [P(76, 62), P(76, 82)], // bench leg
    ],
  ),
  // Dumbbell rowed up to the ribs.
  Pose(
    figure: Figure(
      pelvis: P(40, 58),
      torso: -35,
      arms: [Limb(150, 35)],
      legs: [Limb(95, 92), Limb(91, 95)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
    props: [
      [P(56, 62), P(80, 62)],
      [P(60, 62), P(60, 82)],
      [P(76, 62), P(76, 82)],
    ],
  ),
]);
