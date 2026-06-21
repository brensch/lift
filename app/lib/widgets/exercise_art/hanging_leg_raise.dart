import 'toolkit.dart';

/// Hanging leg raise — bodyweight, side view. Hanging from overhead bar; legs
/// raise from straight-down to horizontal-forward.
ExerciseArt hangingLegRaiseArt() => const ExerciseArt([
  // Frame 0: legs hanging straight down.
  Pose(
    figure: Figure(
      pelvis: P(50, 55),
      torso: -90, // upright
      arms: [Limb(-90, -90), Limb(-87, -87)], // arms straight up to bar
      legs: [Limb(90, 90), Limb(87, 87)], // legs hanging straight down
    ),
    props: [
      [P(20, 8), P(80, 8)], // overhead bar
    ],
  ),
  // Frame 1: legs raised to horizontal.
  Pose(
    figure: Figure(
      pelvis: P(50, 55),
      torso: -90,
      arms: [Limb(-90, -90), Limb(-87, -87)],
      legs: [Limb(0, 5), Limb(3, 8)], // legs horizontal forward
    ),
    props: [
      [P(20, 8), P(80, 8)],
    ],
  ),
]);
