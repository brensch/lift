import 'toolkit.dart';

/// Machine chest press — MACHINE (grey), side view. Seated; arms push handle forward.
ExerciseArt machineChestPressArt() => const ExerciseArt(
  machine: true,
  [
    // Arms bent — handle at chest.
    Pose(
      figure: Figure(
        pelvis: P(32, 68),
        torso: -95, // slightly reclined in seat
        arms: [Limb(-5, 40)], // elbow bent, forearm forward toward handle
        legs: [Limb(10, 95), Limb(13, 98)], // seated legs
      ),
      props: [
        [P(14, 50), P(24, 82)], // seat back
        [P(14, 82), P(38, 82)], // seat bottom
        [P(48, 58), P(58, 58)], // handle
        [P(55, 45), P(55, 82)], // machine vertical frame
        [P(52, 45), P(58, 45)], // machine top
      ],
    ),
    // Arms extended — handle pushed forward.
    Pose(
      figure: Figure(
        pelvis: P(32, 68),
        torso: -95,
        arms: [Limb(-5, -15)], // arm extended forward
        legs: [Limb(10, 95), Limb(13, 98)],
      ),
      props: [
        [P(14, 50), P(24, 82)],
        [P(14, 82), P(38, 82)],
        [P(62, 52), P(72, 52)], // handle (pushed forward)
        [P(55, 45), P(55, 82)],
        [P(52, 45), P(58, 45)],
      ],
    ),
  ],
);
