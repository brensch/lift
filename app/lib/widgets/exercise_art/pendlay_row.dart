import 'toolkit.dart';

/// Pendlay row — free weight, side view. Torso nearly horizontal; bar reset to the floor between reps.
ExerciseArt pendlayRowArt() => const ExerciseArt([
  // Bar on the floor — torso parallel to ground, arms hanging straight down.
  Pose(
    figure: Figure(
      pelvis: P(40, 56),
      torso: -5,
      arms: [Limb(90, 90)],
      legs: [Limb(98, 90), Limb(95, 93)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Bar pulled to the chest — elbows drive back past the torso.
  Pose(
    figure: Figure(
      pelvis: P(40, 56),
      torso: -5,
      arms: [Limb(170, -90)],
      legs: [Limb(98, 90), Limb(95, 93)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
