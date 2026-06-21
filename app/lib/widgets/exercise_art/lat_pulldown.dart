import 'toolkit.dart';

/// Lat pulldown — MACHINE (grey), side view. Arms extended → bar pulled down.
ExerciseArt latPulldownArt() => const ExerciseArt(
  machine: true,
  [
    // Arms extended overhead.
    Pose(
      figure: Figure(
        pelvis: P(36, 70),
        torso: -80,
        arms: [Limb(-82, -86)],
        legs: [Limb(10, 95), Limb(13, 98)],
      ),
      props: [
        [P(43, 8), P(43, 19)], // cable
        [P(31, 19), P(55, 19)], // pulldown bar (high)
        [P(30, 64), P(52, 64)], // thigh pad
        [P(28, 73), P(48, 73)], // seat
      ],
      propDiscs: [PropDisc(P(43, 8), 4)], // pulley
    ),
    // Bar pulled down toward the chest.
    Pose(
      figure: Figure(
        pelvis: P(36, 70),
        torso: -80,
        arms: [Limb(-50, -130)],
        legs: [Limb(10, 95), Limb(13, 98)],
      ),
      props: [
        [P(41, 8), P(41, 25)], // cable
        [P(29, 25), P(53, 25)], // pulldown bar (low)
        [P(30, 64), P(52, 64)], // thigh pad
        [P(28, 73), P(48, 73)], // seat
      ],
      propDiscs: [PropDisc(P(41, 8), 4)], // pulley
    ),
  ],
);
