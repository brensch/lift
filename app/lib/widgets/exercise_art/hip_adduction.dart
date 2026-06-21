import 'toolkit.dart';

/// Hip adduction — machine, front view. Seated; legs squeeze together from wide.
ExerciseArt hipAdductionArt() => const ExerciseArt(
  machine: true,
  view: ExerciseView.front,
  [
    // Start — legs spread wide (against the inner pads).
    Pose(
      figure: Figure(
        pelvis: P(50, 58),
        torso: -90,
        arms: [Limb(100, 100), Limb(80, 80)], // hands on armrests
        legs: [Limb(120, 93), Limb(60, 87)], // thighs splayed outward
      ),
      props: [
        [P(30, 58), P(70, 58)], // seat
        [P(50, 58), P(50, 80)], // seat post
        [P(35, 72), P(35, 78)], // left inner pad (inside the knee)
        [P(65, 72), P(65, 78)], // right inner pad
      ],
    ),
    // End — legs squeezed together.
    Pose(
      figure: Figure(
        pelvis: P(50, 58),
        torso: -90,
        arms: [Limb(100, 100), Limb(80, 80)],
        legs: [Limb(93, 93), Limb(87, 87)], // legs brought together
      ),
      props: [
        [P(30, 58), P(70, 58)],
        [P(50, 58), P(50, 80)],
        [P(44, 72), P(44, 78)], // pads now close together
        [P(56, 72), P(56, 78)],
      ],
    ),
  ],
);
