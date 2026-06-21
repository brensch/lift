import 'toolkit.dart';

/// Chin-up — bodyweight, side view. Hanging arms extended → chin pulled up to bar (underhand).
ExerciseArt chinUpArt() => const ExerciseArt([
  // Dead hang — arms fully extended overhead.
  Pose(
    figure: Figure(
      pelvis: P(50, 68),
      torso: -90,
      arms: [Limb(-90, -90), Limb(-88, -92)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    props: [
      [P(20, 18), P(80, 18)], // overhead bar
    ],
  ),
  // Top — chin near the bar, elbows bent and pulled down (underhand).
  Pose(
    figure: Figure(
      pelvis: P(50, 50),
      torso: -90,
      arms: [Limb(-70, -140), Limb(-72, -138)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    props: [
      [P(20, 18), P(80, 18)], // overhead bar
    ],
  ),
]);
