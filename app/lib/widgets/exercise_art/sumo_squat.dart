import 'toolkit.dart';

/// Sumo squat — bodyweight, front view. Very wide stance, toes out; stand →
/// deep squat.
ExerciseArt sumoSquatArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Stand — very wide stance, hands clasped in front.
    Pose(
      figure: Figure(
        pelvis: P(50, 54),
        torso: -90,
        arms: [Limb(105, 75), Limb(75, 105)], // arms angled to meet in front
        legs: [Limb(210, 88), Limb(-30, 92)], // very wide stance, toes out
      ),
    ),
    // Deep sumo squat — hips low, knees flare very wide.
    Pose(
      figure: Figure(
        pelvis: P(50, 74),
        torso: -82,
        arms: [Limb(105, 75), Limb(75, 105)],
        legs: [Limb(215, 62), Limb(-35, 118)], // knees pushed very wide
      ),
    ),
  ],
);
