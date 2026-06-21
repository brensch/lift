import 'toolkit.dart';

/// Glute kickback — bodyweight, side view. On all fours: hands and one knee
/// down, other leg kicks back and up.
ExerciseArt gluteKickbackArt() => const ExerciseArt([
  // Start: on all fours, kicking leg tucked (knee under hip).
  Pose(
    figure: Figure(
      pelvis: P(52, 44),
      torso: 0, // horizontal — facing right
      arms: [Limb(90, 90)], // arm reaching down, hand on floor
      legs: [
        Limb(110, 90), // support leg: thigh angled down-back, shin vertical down
        Limb(110, 90), // kicking leg same — tucked
      ],
    ),
  ),
  // End: kicking leg extends back and up.
  Pose(
    figure: Figure(
      pelvis: P(52, 44),
      torso: 0,
      arms: [Limb(90, 90)],
      legs: [
        Limb(110, 90),  // support knee stays planted
        Limb(-45, -15), // kicking leg: thigh drives back and up, shin extended
      ],
    ),
  ),
]);
