import 'toolkit.dart';

/// Hip abduction — machine, front view. Seated; legs push outward apart.
ExerciseArt hipAbductionArt() => const ExerciseArt(
  machine: true,
  view: ExerciseView.front,
  [
    // Start — legs together (narrow).
    Pose(
      figure: Figure(
        pelvis: P(50, 58),
        torso: -90,
        arms: [Limb(100, 100), Limb(80, 80)], // hands on armrests
        legs: [Limb(93, 93), Limb(87, 87)], // legs nearly straight down
      ),
      props: [
        [P(30, 58), P(70, 58)], // seat
        [P(50, 58), P(50, 80)], // seat post
        [P(36, 74), P(36, 80)], // left outer pad
        [P(64, 74), P(64, 80)], // right outer pad
      ],
    ),
    // End — legs pushed wide apart.
    Pose(
      figure: Figure(
        pelvis: P(50, 58),
        torso: -90,
        arms: [Limb(100, 100), Limb(80, 80)],
        legs: [Limb(120, 93), Limb(60, 87)], // thighs splayed outward
      ),
      props: [
        [P(30, 58), P(70, 58)],
        [P(50, 58), P(50, 80)],
        [P(25, 74), P(25, 80)], // pads pushed wider
        [P(75, 74), P(75, 80)],
      ],
    ),
  ],
);
