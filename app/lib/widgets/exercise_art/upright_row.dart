import 'toolkit.dart';

/// Upright row — barbell, front view. Bar slides up the body from hips to upper
/// chest, elbows lead high and wide.
ExerciseArt uprightRowArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Start — arms hanging straight down, bar at the hips.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(95, 95), Limb(85, 85)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 34)],
    ),
    // Top — elbows flared high and wide, bar at upper chest / chin level.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(155, -95), Limb(25, -85)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 34)],
    ),
  ],
);
