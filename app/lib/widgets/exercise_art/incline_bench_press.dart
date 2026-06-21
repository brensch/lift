import 'toolkit.dart';

/// Incline bench press — barbell, side view. Bar at chest on incline → press up.
ExerciseArt inclineBenchPressArt() => const ExerciseArt([
  // Bar at chest, torso reclined ~30° up from horizontal.
  Pose(
    figure: Figure(
      pelvis: P(34, 60),
      torso: -30, // ~30° above horizontal (tilted up from lying flat)
      arms: [Limb(200, -30)],
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(20, 70), P(60, 70)], // bench top (inclined)
      [P(20, 70), P(20, 85)], // bench leg (foot)
      [P(55, 70), P(58, 85)], // bench leg (back)
      [P(20, 70), P(55, 50)], // bench backrest incline
    ],
    barbells: [Barbell(hands: [0])],
  ),
  // Lockout — arm extended upward.
  Pose(
    figure: Figure(
      pelvis: P(34, 60),
      torso: -30,
      arms: [Limb(-75, -80)],
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(20, 70), P(60, 70)],
      [P(20, 70), P(20, 85)],
      [P(55, 70), P(58, 85)],
      [P(20, 70), P(55, 50)],
    ],
    barbells: [Barbell(hands: [0])],
  ),
]);
