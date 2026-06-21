import 'toolkit.dart';

/// Barbell hip thrust — free weight, side view. Shoulders on a bench, hips
/// down → full extension, bar over the hips.
ExerciseArt hipThrustArt() => const ExerciseArt([
  // Hips down.
  Pose(
    figure: Figure(
      pelvis: P(50, 68),
      torso: 170, // shoulders back on the bench, head left
      legs: [Limb(-15, 100), Limb(-12, 103)],
    ),
    props: [
      [P(14, 74), P(34, 74)], // shoulder bench
      [P(20, 74), P(20, 86)], // bench leg
    ],
    barbells: [Barbell(hips: true, nudge: P(0, -6))],
  ),
  // Full extension.
  Pose(
    figure: Figure(
      pelvis: P(54, 56),
      torso: 160,
      legs: [Limb(5, 95), Limb(8, 98)],
    ),
    props: [
      [P(14, 74), P(34, 74)],
      [P(20, 74), P(20, 86)],
    ],
    barbells: [Barbell(hips: true, nudge: P(0, -6))],
  ),
]);
