import 'toolkit.dart';

/// Pec deck — MACHINE (grey), front view. Seated; arms open → close in front.
ExerciseArt pecDeckArt() => const ExerciseArt(
  machine: true,
  view: ExerciseView.front,
  [
    // Arms open (start — pads out to sides).
    Pose(
      figure: Figure(
        pelvis: P(50, 68),
        torso: -90,
        arms: [Limb(-10, 50), Limb(-170, 130)], // arms angled out to sides with elbows bent down
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(30, 62), P(70, 62)], // seat
        [P(30, 62), P(30, 80)], // seat left leg
        [P(70, 62), P(70, 80)], // seat right leg
        [P(15, 50), P(15, 90)], // left column
        [P(85, 50), P(85, 90)], // right column
        [P(15, 50), P(30, 58)], // left arm pad
        [P(85, 50), P(70, 58)], // right arm pad
      ],
      propDiscs: [],
    ),
    // Arms closed (end — pads meet in front).
    Pose(
      figure: Figure(
        pelvis: P(50, 68),
        torso: -90,
        arms: [Limb(5, 60), Limb(175, 120)], // arms in front, pads together
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(30, 62), P(70, 62)],
        [P(30, 62), P(30, 80)],
        [P(70, 62), P(70, 80)],
        [P(15, 50), P(15, 90)],
        [P(85, 50), P(85, 90)],
        [P(15, 50), P(44, 55)], // left arm pad (moved in)
        [P(85, 50), P(56, 55)], // right arm pad (moved in)
      ],
      propDiscs: [],
    ),
  ],
);
