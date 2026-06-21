import 'toolkit.dart';

/// Leg press — MACHINE (grey), side view. Reclined, knees bent → extended.
ExerciseArt legPressArt() => const ExerciseArt(
  machine: true,
  [
    // Knees bent.
    Pose(
      figure: Figure(
        pelvis: P(28, 66),
        torso: -110, // reclined back into the seat
        legs: [Limb(-25, -50), Limb(-22, -47)],
      ),
      props: [
        [P(11, 39), P(22, 71)], // backrest
        [P(11, 71), P(30, 71)], // seat
        [P(34, 70), P(78, 40)], // upper rail
        [P(34, 82), P(78, 52)], // lower rail
        [P(70, 36), P(80, 56)], // foot plate
      ],
    ),
    // Extended.
    Pose(
      figure: Figure(
        pelvis: P(28, 66),
        torso: -110,
        legs: [Limb(-28, -28), Limb(-25, -25)],
      ),
      props: [
        [P(11, 39), P(22, 71)],
        [P(11, 71), P(30, 71)],
        [P(34, 70), P(78, 40)],
        [P(34, 82), P(78, 52)],
        [P(70, 36), P(80, 56)],
      ],
    ),
  ],
);
