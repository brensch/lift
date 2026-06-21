import 'toolkit.dart';

/// Russian twist — bodyweight, side view. Seated leaning back ~45°, knees bent,
/// feet up; arms swing side to side (shown as slight torso + arm change).
ExerciseArt russianTwistArt() => const ExerciseArt([
  // Frame 0: arms swung to one side (right).
  Pose(
    figure: Figure(
      pelvis: P(48, 72),
      torso: -130, // leaning back ~40° from vertical
      arms: [Limb(20, 60)], // arms reaching forward-right
      legs: [Limb(-30, 45), Limb(-27, 48)], // knees bent, feet raised
    ),
  ),
  // Frame 1: arms swung to the other side (left/forward).
  Pose(
    figure: Figure(
      pelvis: P(48, 72),
      torso: -125,
      arms: [Limb(155, 120)], // arms reaching to the left
      legs: [Limb(-30, 45), Limb(-27, 48)],
    ),
  ),
]);
