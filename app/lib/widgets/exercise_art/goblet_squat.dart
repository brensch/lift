import 'toolkit.dart';

/// Goblet squat — free weight, front view. Like a back squat but holding a
/// dumbbell at the chest with both hands. Knees splay out, hips drop.
ExerciseArt gobletSquatArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Stand tall — dumbbell held at chest height.
    Pose(
      figure: Figure(
        pelvis: P(50, 54),
        torso: -90,
        arms: [Limb(180, 270), Limb(0, 270)], // both arms bent up, hands at chest
        legs: [Limb(95, 95), Limb(85, 85)],
      ),
      dumbbells: [Dumbbell(hand: 0, nudge: P(13, 0), angle: 90)], // dumbbell at chest centre
    ),
    // Deep — knees out, hips below knees.
    Pose(
      figure: Figure(
        pelvis: P(50, 72),
        torso: -90,
        arms: [Limb(180, 270), Limb(0, 270)],
        legs: [Limb(190, 69), Limb(-10, 111)],
      ),
      dumbbells: [Dumbbell(hand: 0, nudge: P(13, 0), angle: 90)],
    ),
  ],
);
