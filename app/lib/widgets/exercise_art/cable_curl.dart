import 'toolkit.dart';

/// Cable curl — MACHINE (grey), side view. Standing; cable from low pulley at
/// floor; forearm curls up from extended to contracted.
ExerciseArt cableCurlArt() => const ExerciseArt(
  machine: true,
  [
    // Arm down, cable taut from floor pulley to hand.
    Pose(
      figure: Figure(
        pelvis: P(42, 52),
        torso: -90,
        arms: [Limb(90, 90)],
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(72, 90), P(72, 82)], // cable machine upright
        [P(66, 82), P(78, 82)], // base of machine
        [P(72, 84), P(55, 90)], // cable from pulley to hand (arm down)
      ],
      propDiscs: [PropDisc(P(72, 84), 3)], // low pulley
    ),
    // Curled up.
    Pose(
      figure: Figure(
        pelvis: P(42, 52),
        torso: -90,
        arms: [Limb(90, -60)],
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(72, 90), P(72, 82)],
        [P(66, 82), P(78, 82)],
        [P(72, 84), P(55, 30)], // cable runs up to the curled hand
      ],
      propDiscs: [PropDisc(P(72, 84), 3)],
    ),
  ],
);
