import 'toolkit.dart';

/// Incline dumbbell press — dumbbell, side view. Torso ~30° reclined, dumbbell at chest → press up.
ExerciseArt inclineDumbbellPressArt() => const ExerciseArt([
  // Dumbbell at chest, torso reclined ~30° up from horizontal.
  Pose(
    figure: Figure(
      pelvis: P(34, 60),
      torso: -30,
      arms: [Limb(200, -30)],
      legs: [Limb(150, 95), Limb(146, 100)],
    ),
    props: [
      [P(20, 70), P(60, 70)],
      [P(20, 70), P(20, 85)],
      [P(55, 70), P(58, 85)],
      [P(20, 70), P(55, 50)],
    ],
    dumbbells: [Dumbbell(hand: 0)],
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
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
