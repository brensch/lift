import 'toolkit.dart';

/// Cable fly — machine, front view. Standing; arms wide → sweep together in front of chest.
ExerciseArt cableFlyArt() => const ExerciseArt(
  machine: true,
  view: ExerciseView.front,
  [
    // Arms wide (start — cables taut from high anchors).
    Pose(
      figure: Figure(
        pelvis: P(50, 65),
        torso: -90,
        arms: [Limb(-30, 30), Limb(-150, 150)], // arms angled out to sides
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        // Left cable: from pulley to hand
        [P(8, 15), P(22, 50)],
        // Right cable: from pulley to hand
        [P(92, 15), P(78, 50)],
        // Left column
        [P(8, 10), P(8, 90)],
        // Right column
        [P(92, 10), P(92, 90)],
      ],
      propDiscs: [
        PropDisc(P(8, 15), 5),  // left pulley
        PropDisc(P(92, 15), 5), // right pulley
      ],
    ),
    // Arms together (end — cables meet in front of chest).
    Pose(
      figure: Figure(
        pelvis: P(50, 65),
        torso: -90,
        arms: [Limb(10, -30), Limb(170, -150)], // arms angled slightly down in front
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        // Left cable: from pulley to hand (now close to centre)
        [P(8, 15), P(44, 52)],
        // Right cable: from pulley to hand
        [P(92, 15), P(56, 52)],
        // Left column
        [P(8, 10), P(8, 90)],
        // Right column
        [P(92, 10), P(92, 90)],
      ],
      propDiscs: [
        PropDisc(P(8, 15), 5),
        PropDisc(P(92, 15), 5),
      ],
    ),
  ],
);
