import 'toolkit.dart';

/// Dumbbell shoulder press — dumbbells, front view. Shoulders → overhead.
ExerciseArt dumbbellShoulderPressArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Start — dumbbells at shoulder height, elbows wide and low, forearms vertical.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(160, -90), Limb(20, -90)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      dumbbells: [Dumbbell(hand: 0), Dumbbell(hand: 1)],
    ),
    // Lockout — pressed straight overhead.
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
