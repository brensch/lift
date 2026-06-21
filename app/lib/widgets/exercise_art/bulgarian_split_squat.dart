import 'toolkit.dart';

/// Bulgarian split squat — bodyweight, side view. Rear foot up on a bench.
ExerciseArt bulgarianSplitSquatArt() => const ExerciseArt([
  // Top.
  Pose(
    figure: Figure(
      pelvis: P(52, 50),
      torso: -88,
      arms: [Limb(95, 95)],
      legs: [Limb(88, 92), Limb(131, 191)], // front straight, rear on bench
    ),
    props: [
      [P(14, 62), P(30, 62)], // bench top
      [P(20, 62), P(20, 82)], // bench leg
    ],
  ),
  // Bottom — front knee bends deep, rear knee drops.
  Pose(
    figure: Figure(
      pelvis: P(52, 58),
      torso: -86,
      arms: [Limb(95, 95)],
      legs: [Limb(55, 110), Limb(131, 191)],
    ),
    props: [
      [P(14, 62), P(30, 62)],
      [P(20, 62), P(20, 82)],
    ],
  ),
]);
