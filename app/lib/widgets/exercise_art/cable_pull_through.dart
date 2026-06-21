import 'toolkit.dart';

/// Cable pull-through — machine, side view. Cable from low pulley behind runs
/// between the legs; hinge forward → stand up to extend hips.
ExerciseArt cablePullThroughArt() => const ExerciseArt(
  machine: true,
  [
    // Hinged forward — torso angled down, hips back over the pulley.
    Pose(
      figure: Figure(
        pelvis: P(44, 58),
        torso: -30,
        arms: [Limb(150, 150)], // arms reaching back between legs to cable
        legs: [Limb(60, 110), Limb(63, 107)],
      ),
      props: [
        [P(80, 78), P(80, 90)], // pulley post
        [P(76, 82), P(84, 82)], // pulley crossbar
        [P(80, 80), P(50, 70)], // cable running between legs to hands
      ],
      propDiscs: [PropDisc(P(80, 80), 4)], // pulley disc
    ),
    // Standing — hips extended, upright, arms down holding cable.
    Pose(
      figure: Figure(
        pelvis: P(48, 52),
        torso: -90,
        arms: [Limb(150, 150)], // arms still angled back/down
        legs: [Limb(91, 91), Limb(89, 89)],
      ),
      props: [
        [P(80, 78), P(80, 90)],
        [P(76, 82), P(84, 82)],
        [P(80, 80), P(58, 80)], // cable now more horizontal
      ],
      propDiscs: [PropDisc(P(80, 80), 4)],
    ),
  ],
);
