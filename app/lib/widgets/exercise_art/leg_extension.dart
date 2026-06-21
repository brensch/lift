import 'toolkit.dart';

/// Leg extension — MACHINE (grey), side view. Seated; shin hangs down → extends
/// forward to horizontal.
ExerciseArt legExtensionArt() => const ExerciseArt(
  machine: true,
  [
    // Seated, shin hanging down.
    Pose(
      figure: Figure(
        pelvis: P(35, 58),
        torso: -90,
        arms: [Limb(10, 80)], // one arm gripping seat handle
        legs: [Limb(0, 91), Limb(2, 89)], // thighs horizontal forward, shins hang down
      ),
      props: [
        [P(10, 48), P(10, 82)], // seat back
        [P(10, 68), P(48, 68)], // seat bottom
        [P(48, 68), P(48, 82)], // seat front leg
        [P(10, 82), P(55, 82)], // base
      ],
      propDiscs: [PropDisc(P(54, 88), 5)], // ankle roller disc at hanging foot
    ),
    // Shin extended forward to horizontal.
    Pose(
      figure: Figure(
        pelvis: P(35, 58),
        torso: -90,
        arms: [Limb(10, 80)],
        legs: [Limb(0, 0), Limb(2, 2)], // thighs horizontal, shins also horizontal
      ),
      props: [
        [P(10, 48), P(10, 82)],
        [P(10, 68), P(48, 68)],
        [P(48, 68), P(48, 82)],
        [P(10, 82), P(55, 82)],
      ],
      propDiscs: [PropDisc(P(73, 58), 5)], // ankle roller disc moves up with extended shin
    ),
  ],
);
