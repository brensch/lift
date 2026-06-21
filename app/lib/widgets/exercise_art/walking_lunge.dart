import 'toolkit.dart';

/// Walking lunge — bodyweight, side view. Forward stride into a deep lunge.
ExerciseArt walkingLungeArt() => const ExerciseArt([
  // Stand.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
  ),
  // Lunge — front knee forward and bent, back knee dropped low behind.
  Pose(
    figure: Figure(
      pelvis: P(46, 58),
      torso: -90,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(42, 115), Limb(148, 62)],
    ),
  ),
]);
