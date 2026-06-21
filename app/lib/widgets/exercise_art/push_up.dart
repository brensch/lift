import 'toolkit.dart';

/// Push-up — bodyweight, side view. Straight body on hands + toes; body lowers then rises.
ExerciseArt pushUpArt() => const ExerciseArt([
  // Bottom position — chest near floor, elbows bent.
  Pose(
    figure: Figure(
      pelvis: P(44, 70),
      torso: 3, // nearly horizontal, head to the right
      arms: [Limb(160, 90)], // elbow bent, forearm goes down to hand on floor
      legs: [Limb(176, 176), Limb(174, 174)], // legs straight back
    ),
  ),
  // Top position — arms extended, body raised.
  Pose(
    figure: Figure(
      pelvis: P(44, 60),
      torso: 3,
      arms: [Limb(155, 55)], // arm more extended, body pushed up
      legs: [Limb(176, 176), Limb(174, 174)],
    ),
  ),
]);
