import 'toolkit.dart';

/// Mountain climber — bodyweight, side view. Top-of-pushup position; one knee
/// drives forward toward the chest, then back.
ExerciseArt mountainClimberArt() => const ExerciseArt([
  // Frame 0: right leg extended back (plank/pushup position).
  Pose(
    figure: Figure(
      pelvis: P(50, 48),
      torso: 10, // nearly horizontal, slight incline
      arms: [Limb(170, 90)], // arm straight down to floor (pushup top)
      legs: [Limb(5, 90), Limb(8, 87)], // both legs extended back
    ),
    props: [
      [P(10, 80), P(90, 80)], // floor
    ],
  ),
  // Frame 1: one knee driven forward toward chest.
  Pose(
    figure: Figure(
      pelvis: P(50, 48),
      torso: 10,
      arms: [Limb(170, 90)],
      legs: [Limb(-40, 80), Limb(8, 87)], // front leg: thigh up-forward, shin down
    ),
    props: [
      [P(10, 80), P(90, 80)],
    ],
  ),
]);
