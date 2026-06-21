import 'toolkit.dart';

/// Arnold press — dumbbells, front view. Hands in front of face → overhead.
ExerciseArt arnoldPressArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Start — elbows narrow and low at chin height, forearms vertical and close.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(-60, -90), Limb(-120, -90)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      dumbbells: [Dumbbell(hand: 0), Dumbbell(hand: 1)],
    ),
    // Lockout — rotated out and pressed overhead.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(-95, -95), Limb(-85, -85)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      dumbbells: [Dumbbell(hand: 0), Dumbbell(hand: 1)],
    ),
  ],
);
