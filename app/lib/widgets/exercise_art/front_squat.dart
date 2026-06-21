import 'toolkit.dart';

/// Front squat — free weight, front view. Bar in the front rack at the
/// shoulders; body descends into the squat.
ExerciseArt frontSquatArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Stand, bar racked on the front shoulders.
    Pose(
      figure: Figure(
        pelvis: P(50, 54),
        torso: -90,
        arms: [Limb(153, -56), Limb(27, -124)], // elbows up, hands at shoulders
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 34)],
    ),
    // Deep.
    Pose(
      figure: Figure(
        pelvis: P(50, 72),
        torso: -90,
        arms: [Limb(153, -56), Limb(27, -124)],
        legs: [Limb(190, 69), Limb(-10, 111)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 34)],
    ),
  ],
);
