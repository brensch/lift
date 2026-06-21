import 'toolkit.dart';

/// Shrug — free weight, side view. Standing, barbell at hips; whole figure rises slightly as traps shrug.
ExerciseArt shrugArt() => const ExerciseArt([
  // Start — arms hanging, barbell at hips.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Shrug — whole figure rises ~3 units, shoulders pulled up.
  Pose(
    figure: Figure(
      pelvis: P(50, 49),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
