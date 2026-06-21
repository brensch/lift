import 'toolkit.dart';

/// Face pull — MACHINE (grey), side view. Standing; arms extended to high pulley → pulled to face, elbows high.
/// pelvis=(50,60), torso=-90, neck=(50,34), head=(50,25).
/// Frame0 arm Limb(-30,-30): elbow=(61,28), hand=(71,22) → cable to P(90,20).
/// Frame1 arm Limb(-100,-40): elbow=(48,21), hand=(57,14) → handle at face level.
ExerciseArt facePullArt() => const ExerciseArt(
  machine: true,
  [
    // Arms extended toward the high pulley.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(-30, -30)],
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(90, 20), P(90, 72)], // cable machine upright
        [P(90, 20), P(71, 22)], // cable from pulley to hand
      ],
      propDiscs: [PropDisc(P(90, 20), 4)], // pulley
    ),
    // Hands pulled to face, elbows flared high and back.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(-100, -40)],
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(90, 20), P(90, 72)], // cable machine upright
        [P(90, 20), P(57, 14)], // cable from pulley to hand
      ],
      propDiscs: [PropDisc(P(90, 20), 4)], // pulley
    ),
  ],
);
