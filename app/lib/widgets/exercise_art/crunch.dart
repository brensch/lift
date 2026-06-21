import 'toolkit.dart';

/// Crunch — bodyweight, side view (supine, knees up). Torso curls up off the floor.
ExerciseArt crunchArt() => const ExerciseArt([
  // Lying flat.
  Pose(
    figure: Figure(
      pelvis: P(48, 72),
      torso: 185, // head to the left, flat on the floor
      legs: [Limb(-30, 110), Limb(-27, 113)],
    ),
  ),
  // Curled up.
  Pose(
    figure: Figure(
      pelvis: P(48, 72),
      torso: 215, // shoulders lift toward the knees
      legs: [Limb(-30, 110), Limb(-27, 113)],
    ),
  ),
]);
