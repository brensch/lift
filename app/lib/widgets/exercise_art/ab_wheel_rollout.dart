import 'toolkit.dart';

/// Ab wheel rollout — bodyweight, side view. Kneeling; arms reach forward
/// rolling a wheel out so body extends low, then contracts back.
ExerciseArt abWheelRolloutArt() => const ExerciseArt([
  // Frame 0: contracted — kneeling upright, wheel close.
  Pose(
    figure: Figure(
      pelvis: P(48, 68),
      torso: -80, // nearly upright
      arms: [Limb(-30, 60)], // arms angled down-forward to wheel
      legs: [Limb(90, -90), Limb(87, -87)], // kneeling
    ),
    props: [
      [P(15, 82), P(80, 82)], // floor
    ],
    propDiscs: [PropDisc(P(62, 77), 5)], // wheel disc at hands
  ),
  // Frame 1: extended — body stretched low, wheel rolled far forward.
  Pose(
    figure: Figure(
      pelvis: P(40, 60),
      torso: 5, // body nearly horizontal
      arms: [Limb(10, 30)], // arms reaching far forward
      legs: [Limb(90, -80), Limb(87, -77)], // knees on floor, shins back
    ),
    props: [
      [P(15, 82), P(80, 82)],
    ],
    propDiscs: [PropDisc(P(75, 77), 5)], // wheel rolled forward
  ),
]);
