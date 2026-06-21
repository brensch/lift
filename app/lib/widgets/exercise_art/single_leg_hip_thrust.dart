import 'toolkit.dart';

/// Single-leg hip thrust — free weight, side view. Shoulders on bench, one leg
/// planted, other leg extended straight; hips drive up.
ExerciseArt singleLegHipThrustArt() => const ExerciseArt([
  // Hips down.
  Pose(
    figure: Figure(
      pelvis: P(50, 68),
      torso: 170, // shoulders back on bench
      arms: [Limb(95, 95)], // arm resting down (not relevant)
      legs: [
        Limb(-15, 100), // planted leg bent, foot on floor
        Limb(-5, 0),    // extended leg: thigh angled slightly up, shin forward
      ],
    ),
    props: [
      [P(14, 74), P(34, 74)], // bench top
      [P(20, 74), P(20, 86)], // bench leg
    ],
    barbells: [Barbell(hips: true, nudge: P(0, -6))],
  ),
  // Full extension.
  Pose(
    figure: Figure(
      pelvis: P(54, 56),
      torso: 160,
      arms: [Limb(95, 95)],
      legs: [
        Limb(5, 95),   // planted leg extended, foot on floor
        Limb(-20, 0),  // other leg extended straight forward and slightly up
      ],
    ),
    props: [
      [P(14, 74), P(34, 74)],
      [P(20, 74), P(20, 86)],
    ],
    barbells: [Barbell(hips: true, nudge: P(0, -6))],
  ),
]);
