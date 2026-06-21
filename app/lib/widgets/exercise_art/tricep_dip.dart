import 'toolkit.dart';

/// Tricep dip — bodyweight, side view. Upright torso between parallel bars;
/// body lowers by bending arms, then pushes back up.
ExerciseArt tricepDipArt() => const ExerciseArt([
  // Bottom position — arms bent, body lowered.
  Pose(
    figure: Figure(
      pelvis: P(50, 60),
      torso: -90, // upright torso
      arms: [Limb(60, 150)], // upper arm angled down-forward, forearm folds back
      legs: [Limb(100, 80), Limb(97, 77)], // legs hanging/slightly bent
    ),
    props: [
      // Left bar
      [P(30, 30), P(30, 70)],
      // Right bar
      [P(70, 30), P(70, 70)],
    ],
  ),
  // Top position — arms extended, body raised.
  Pose(
    figure: Figure(
      pelvis: P(50, 48),
      torso: -90,
      arms: [Limb(-35, 60)], // arms mostly extended, hands on bars
      legs: [Limb(100, 80), Limb(97, 77)],
    ),
    props: [
      [P(30, 30), P(30, 70)],
      [P(70, 30), P(70, 70)],
    ],
  ),
]);
