import 'toolkit.dart';

/// Nordic curl — bodyweight, side view. Kneeling upright with ankles anchored;
/// the body lowers forward toward the floor then back up.
ExerciseArt nordicCurlArt() => const ExerciseArt([
  // Upright — kneeling tall. Knees on floor, shins behind, ankles anchored.
  Pose(
    figure: Figure(
      pelvis: P(50, 58),
      torso: -90,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(90, 180), Limb(88, 180)], // thighs straight down, shins point back
    ),
    props: [
      [P(36, 82), P(64, 82)], // anchor bar
      [P(36, 82), P(36, 90)], // anchor leg left
      [P(64, 82), P(64, 90)], // anchor leg right
    ],
  ),
  // Lowered forward — body tilts ~50° forward, ankles still on the floor.
  Pose(
    figure: Figure(
      pelvis: P(38, 68),
      torso: -40, // tilted forward significantly
      arms: [Limb(130, 50), Limb(128, 52)], // arms reaching slightly forward
      legs: [Limb(90, 180), Limb(88, 180)], // legs unchanged — kneeling
    ),
    props: [
      [P(36, 82), P(64, 82)],
      [P(36, 82), P(36, 90)],
      [P(64, 82), P(64, 90)],
    ],
  ),
]);
