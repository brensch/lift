import 'toolkit.dart';

/// Lateral raise — dumbbells, front view. Arms at sides → T (shoulder height).
ExerciseArt lateralRaiseArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Start — arms hanging at the sides.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(95, 95), Limb(85, 85)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      dumbbells: [Dumbbell(hand: 0), Dumbbell(hand: 1)],
    ),
    // Top — arms raised out to shoulder height, forming a T.
    Pose(
      figure: Figure(
        pelvis: P(50, 60),
        torso: -90,
        arms: [Limb(175, 170), Limb(5, 10)],
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      dumbbells: [Dumbbell(hand: 0), Dumbbell(hand: 1)],
    ),
  ],
);
