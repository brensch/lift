import 'toolkit.dart';

/// Cable crunch — MACHINE (grey), side view. Kneeling; torso crunches
/// down/forward against a high cable held near the head.
ExerciseArt cableCrunchArt() => const ExerciseArt(
  machine: true,
  [
    // Frame 0: torso upright, arms holding cable near head/neck.
    Pose(
      figure: Figure(
        pelvis: P(45, 72),
        torso: -85, // nearly upright kneeling
        arms: [Limb(-70, -20)], // hands near head holding rope
        legs: [Limb(90, -90), Limb(87, -87)], // kneeling: thigh down, shin back
      ),
      props: [
        [P(75, 5), P(75, 18)], // cable from pulley
        [P(55, 18), P(75, 18)], // cable going to hands
        [P(15, 80), P(70, 80)], // floor/mat
      ],
      propDiscs: [PropDisc(P(75, 5), 4)], // high pulley
    ),
    // Frame 1: torso crunched forward/down toward knees.
    Pose(
      figure: Figure(
        pelvis: P(45, 72),
        torso: -40, // crunched forward
        arms: [Limb(-60, 10)], // arms still holding near head
        legs: [Limb(90, -90), Limb(87, -87)],
      ),
      props: [
        [P(75, 5), P(75, 35)], // cable from pulley (longer now, figure leaned)
        [P(55, 35), P(75, 35)],
        [P(15, 80), P(70, 80)],
      ],
      propDiscs: [PropDisc(P(75, 5), 4)],
    ),
  ],
);
