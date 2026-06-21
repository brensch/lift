import 'toolkit.dart';

/// Rear delt fly — dumbbells, side view. Hinged ~50° forward; arms hang then
/// open out wide to the sides.
ExerciseArt rearDeltFlyArt() => const ExerciseArt([
  // Hang — torso hinged forward, arms hanging down toward the floor.
  Pose(
    figure: Figure(
      pelvis: P(44, 58),
      torso: -45,
      arms: [Limb(90, 90), Limb(91, 91)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Fly — arm raised wide, perpendicular to the torso (up and back).
  Pose(
    figure: Figure(
      pelvis: P(44, 58),
      torso: -45,
      arms: [Limb(-45, -45), Limb(91, 91)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
