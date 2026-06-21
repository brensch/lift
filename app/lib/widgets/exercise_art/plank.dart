import 'toolkit.dart';

/// Plank — bodyweight, side view. Body horizontal on forearms + toes.
/// Isometric: tiny hip sag vs. perfect hold to show the exercise.
ExerciseArt plankArt() => const ExerciseArt([
  // Frame 0: hips very slightly dropped (natural hold position).
  Pose(
    figure: Figure(
      pelvis: P(42, 56),
      torso: 0, // horizontal, neck/head to the right
      arms: [Limb(130, 90)], // upper arm goes back-down, forearm straight down to floor
      legs: [Limb(178, 92), Limb(175, 89)], // legs extend left (backward), nearly horizontal
    ),
    props: [
      [P(10, 82), P(90, 82)], // floor line
    ],
  ),
  // Frame 1: hips slightly raised (perfect plank).
  Pose(
    figure: Figure(
      pelvis: P(42, 53),
      torso: 0,
      arms: [Limb(130, 90)],
      legs: [Limb(178, 90), Limb(175, 87)],
    ),
    props: [
      [P(10, 82), P(90, 82)],
    ],
  ),
]);
