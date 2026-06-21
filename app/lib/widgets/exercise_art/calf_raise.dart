import 'toolkit.dart';

/// Calf raise — bodyweight, side view. Standing; whole body rises as heels
/// lift off the ground — rise up onto the toes.
ExerciseArt calfRaiseArt() => const ExerciseArt([
  // Heels flat on the ground — standing position.
  Pose(
    figure: Figure(
      pelvis: P(50, 54),
      torso: -90,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
  ),
  // Up on toes — whole body lifted ~5 units, shins slightly forward as heel lifts.
  Pose(
    figure: Figure(
      pelvis: P(50, 48),
      torso: -90,
      arms: [Limb(91, 91), Limb(89, 89)],
      legs: [Limb(91, 70), Limb(89, 74)], // shin angles forward more as heel lifts
    ),
  ),
]);
