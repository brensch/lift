import 'toolkit.dart';

/// Chest dip — bodyweight, side view. On parallel bars; body lowers then rises.
ExerciseArt chestDipArt() => const ExerciseArt([
  // Bottom position — body lowered between bars, elbows bent.
  Pose(
    figure: Figure(
      pelvis: P(42, 65),
      torso: -75, // slight forward lean for chest dip
      arms: [Limb(75, 140)], // upper arm down, forearm angles back up to hand on bar
      legs: [Limb(115, 55), Limb(112, 52)], // legs hanging/bent behind
    ),
    props: [
      [P(22, 40), P(22, 88)], // front bar post
      [P(60, 40), P(60, 88)], // back bar post
      [P(18, 40), P(26, 40)], // front bar handle
      [P(56, 40), P(64, 40)], // back bar handle
    ],
  ),
  // Top position — arms extended, body raised.
  Pose(
    figure: Figure(
      pelvis: P(42, 50),
      torso: -80,
      arms: [Limb(75, 115)], // arm more extended toward straight
      legs: [Limb(115, 55), Limb(112, 52)],
    ),
    props: [
      [P(22, 40), P(22, 88)],
      [P(60, 40), P(60, 88)],
      [P(18, 40), P(26, 40)],
      [P(56, 40), P(64, 40)],
    ],
  ),
]);
