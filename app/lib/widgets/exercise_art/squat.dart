import 'toolkit.dart';

/// Back squat — free weight, front view. Body descends, knees splay, hips drop.
ExerciseArt squatArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Stand tall.
    Pose(
      figure: Figure(
        pelvis: P(50, 54),
        torso: -90,
        arms: [Limb(180, 180), Limb(0, 0)], // out to the bar
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 54)],
    ),
    // Deep — knees out, hips below knees.
    Pose(
      figure: Figure(
        pelvis: P(50, 72),
        torso: -90,
        arms: [Limb(180, 180), Limb(0, 0)],
        legs: [Limb(190, 69), Limb(-10, 111)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 54)],
    ),
  ],
);
