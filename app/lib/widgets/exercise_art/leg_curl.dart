import 'toolkit.dart';

/// Lying leg curl — MACHINE (grey), side view (prone, head left). Lower legs
/// extended → curled up toward the glutes.
ExerciseArt legCurlArt() => const ExerciseArt(
  machine: true,
  [
    // Legs extended along the pad.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: 180, // prone, head to the left
        legs: [Limb(2, 2), Limb(5, 5)],
      ),
      props: [
        [P(22, 63), P(74, 63)], // pad
        [P(30, 63), P(30, 80)], // support
        [P(66, 63), P(66, 80)], // support
      ],
      propDiscs: [PropDisc(P(88, 61), 4.5)], // ankle roller
    ),
    // Heels curled up toward the glutes.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: 180,
        legs: [Limb(2, 235), Limb(5, 238)],
      ),
      props: [
        [P(22, 63), P(74, 63)],
        [P(30, 63), P(30, 80)],
        [P(66, 63), P(66, 80)],
      ],
      propDiscs: [PropDisc(P(58, 45), 4.5)], // roller follows the heel
    ),
  ],
);
