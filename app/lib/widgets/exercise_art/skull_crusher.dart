import 'toolkit.dart';

/// Skull crusher — barbell, side view. Lying on flat bench; bar lowers to
/// forehead then extends straight up.
ExerciseArt skullCrusherArt() => const ExerciseArt([
  // Bar at forehead (lowered position).
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0, // lying flat, head to the right
      arms: [Limb(-88, 160)], // upper arm vertical, forearm drops toward face
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)], // bench top
      [P(34, 61), P(34, 82)], // bench leg
      [P(58, 61), P(58, 82)], // bench leg
    ],
    barbells: [Barbell(hands: [0])],
  ),
  // Bar extended straight up (lockout).
  Pose(
    figure: Figure(
      pelvis: P(34, 57),
      torso: 0,
      arms: [Limb(-88, -90)], // upper arm vertical, forearm extends straight up
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(28, 61), P(64, 61)],
      [P(34, 61), P(34, 82)],
      [P(58, 61), P(58, 82)],
    ],
    barbells: [Barbell(hands: [0])],
  ),
]);
