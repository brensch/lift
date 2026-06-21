import 'toolkit.dart';

/// Sit-up — bodyweight, side view (supine → full sit-up). Torso comes all the
/// way up to sitting upright — bigger range than crunch.
ExerciseArt sitUpArt() => const ExerciseArt([
  // Frame 0: lying flat, arms folded across chest.
  Pose(
    figure: Figure(
      pelvis: P(48, 72),
      torso: 185, // lying, head to left
      arms: [Limb(210, 270)], // arms resting across chest
      legs: [Limb(-25, 110), Limb(-22, 113)], // knees bent
    ),
  ),
  // Frame 1: fully upright — sitting up.
  Pose(
    figure: Figure(
      pelvis: P(48, 72),
      torso: -90, // fully upright
      arms: [Limb(30, 90)], // arms out slightly for balance
      legs: [Limb(-25, 110), Limb(-22, 113)],
    ),
  ),
]);
