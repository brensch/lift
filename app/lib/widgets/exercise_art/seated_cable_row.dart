import 'toolkit.dart';

/// Seated cable row — MACHINE (grey), side view. Arm extended to low pulley → handle pulled to torso.
/// Figure sits upright facing left toward the cable machine.
/// pelvis=(46,68), torso=-90, neck=(46,42).
/// Frame0 arm Limb(180,180): elbow=(33,42), hand=(21,42).
/// Frame1 arm Limb(160,0):   elbow=(21,47), hand=(33,47) — pulled to torso.
ExerciseArt seatedCableRowArt() => const ExerciseArt(
  machine: true,
  [
    // Arms extended left toward the low pulley.
    Pose(
      figure: Figure(
        pelvis: P(46, 68),
        torso: -90,
        arms: [Limb(180, 180)],
        legs: [Limb(10, 90), Limb(12, 93)],
      ),
      props: [
        [P(8, 68), P(8, 88)],   // cable machine tower
        [P(8, 68), P(21, 42)],  // cable from pulley to hand
        [P(34, 74), P(60, 74)], // seat
        [P(8, 88), P(60, 88)],  // footplate
      ],
      propDiscs: [PropDisc(P(8, 68), 4)], // pulley
    ),
    // Handle pulled back to the torso.
    Pose(
      figure: Figure(
        pelvis: P(46, 68),
        torso: -90,
        arms: [Limb(160, 0)],
        legs: [Limb(10, 90), Limb(12, 93)],
      ),
      props: [
        [P(8, 68), P(8, 88)],   // cable machine tower
        [P(8, 68), P(33, 47)],  // cable from pulley to hand (shortened)
        [P(34, 74), P(60, 74)], // seat
        [P(8, 88), P(60, 88)],  // footplate
      ],
      propDiscs: [PropDisc(P(8, 68), 4)], // pulley
    ),
  ],
);
