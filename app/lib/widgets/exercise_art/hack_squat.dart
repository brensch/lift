import 'toolkit.dart';

/// Hack squat — MACHINE (grey), side view. Reclined back against angled pad;
/// squat down then up. Feet on foot plate.
ExerciseArt hackSquatArt() => const ExerciseArt(
  machine: true,
  [
    // Standing (top of movement) — back reclined on the angled pad.
    Pose(
      figure: Figure(
        pelvis: P(46, 58),
        torso: -115, // reclined ~25° from vertical
        arms: [Limb(30, 90), Limb(30, 90)], // hands gripping side handles
        legs: [Limb(91, 91), Limb(89, 89)], // legs fairly straight at top
      ),
      props: [
        [P(22, 25), P(62, 88)], // angled back pad
        [P(22, 88), P(70, 88)], // foot plate
        [P(62, 88), P(62, 95)], // lower rail stub
        [P(22, 25), P(22, 95)], // upper rail
      ],
    ),
    // Bottom of squat — knees bent, hips lower.
    Pose(
      figure: Figure(
        pelvis: P(40, 72),
        torso: -115,
        arms: [Limb(30, 90), Limb(30, 90)],
        legs: [Limb(55, 118), Limb(53, 120)], // deep knee bend
      ),
      props: [
        [P(22, 25), P(62, 88)],
        [P(22, 88), P(70, 88)],
        [P(62, 88), P(62, 95)],
        [P(22, 25), P(22, 95)],
      ],
    ),
  ],
);
