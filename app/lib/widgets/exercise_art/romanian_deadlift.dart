import 'toolkit.dart';

/// Romanian deadlift — free weight, side view. Stand → hip hinge (legs stay
/// near-straight, bar slides down the thighs).
ExerciseArt romanianDeadliftArt() => const ExerciseArt([
  // Standing tall.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Hinge — hips back, flat back, slight knee bend, bar at the shins.
  Pose(
    figure: Figure(
      pelvis: P(44, 54),
      torso: -40,
      arms: [Limb(115, 115)],
      legs: [Limb(85, 92), Limb(82, 95)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
