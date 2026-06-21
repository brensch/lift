import 'toolkit.dart';

/// Step up — bodyweight, side view. One foot steps up onto a box; body rises.
ExerciseArt stepUpArt() => const ExerciseArt([
  // Bottom — one foot on the box, ready to step up; other foot on the floor.
  Pose(
    figure: Figure(
      pelvis: P(46, 62),
      torso: -88,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(52, 108), Limb(98, 78)], // front leg up on box, back leg on floor
    ),
    props: [
      [P(30, 78), P(30, 90), P(68, 90), P(68, 78)], // box outline (3 sides)
    ],
  ),
  // Top — fully stepped up, both feet near box level; body upright.
  Pose(
    figure: Figure(
      pelvis: P(46, 48),
      torso: -90,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(91, 91), Limb(89, 89)], // standing tall on top
    ),
    props: [
      [P(30, 78), P(30, 90), P(68, 90), P(68, 78)],
    ],
  ),
]);
