import 'toolkit.dart';

/// Lunge — bodyweight, side view. Stand → drop into the lunge.
ExerciseArt lungeArt() => const ExerciseArt([
  // Stand.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
  ),
  // Lunge — front knee forward, back knee dropped behind.
  Pose(
    figure: Figure(
      pelvis: P(48, 56),
      torso: -88,
      arms: [Limb(90, 90)],
      legs: [Limb(50, 110), Limb(145, 65)],
    ),
  ),
]);
