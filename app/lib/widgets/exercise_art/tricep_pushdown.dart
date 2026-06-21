import 'toolkit.dart';

/// Tricep pushdown — MACHINE (grey), side view. Standing; high cable pulley;
/// upper arm pinned vertical, forearm extends DOWN from ~-30° to 90°.
ExerciseArt tricepPushdownArt() => const ExerciseArt(
  machine: true,
  [
    // Forearm up (start — elbow bent, hands near chest).
    Pose(
      figure: Figure(
        pelvis: P(42, 52),
        torso: -90,
        arms: [Limb(90, -30)], // upper arm pinned down, forearm up
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(72, 5), P(72, 50)], // machine upright
        [P(66, 50), P(78, 50)], // base
        [P(72, 8), P(55, 28)],  // cable from pulley to hand
      ],
      propDiscs: [PropDisc(P(72, 8), 3)], // high pulley
    ),
    // Forearm pushed straight down (lockout).
    Pose(
      figure: Figure(
        pelvis: P(42, 52),
        torso: -90,
        arms: [Limb(90, 90)], // upper arm still pinned, forearm extends down
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(72, 5), P(72, 50)],
        [P(66, 50), P(78, 50)],
        [P(72, 8), P(55, 65)], // cable follows hand to extended position
      ],
      propDiscs: [PropDisc(P(72, 8), 3)],
    ),
  ],
);
