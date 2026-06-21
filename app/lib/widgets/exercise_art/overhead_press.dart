import 'toolkit.dart';

/// Overhead press — free weight, front view. Bar at shoulders → locked overhead.
ExerciseArt overheadPressArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Rack — elbows out, bar at the shoulders.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(153, -56), Limb(27, -124)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 34)],
    ),
    // Lockout — pressed straight up.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(-95, -95), Limb(-85, -85)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 34)],
    ),
  ],
);
