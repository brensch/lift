import 'toolkit.dart';

/// Glute bridge — bodyweight, side view (supine). Shoulders down, hips drive up.
ExerciseArt gluteBridgeArt() => const ExerciseArt([
  // Hips down near the floor.
  Pose(
    figure: Figure(
      pelvis: P(48, 76),
      torso: 178, // lying back, head to the left
      legs: [Limb(-25, 110), Limb(-22, 113)],
    ),
  ),
  // Hips bridged up.
  Pose(
    figure: Figure(
      pelvis: P(48, 64),
      torso: 152, // tilts so the shoulders stay on the floor
      legs: [Limb(5, 95), Limb(8, 98)],
    ),
  ),
]);
