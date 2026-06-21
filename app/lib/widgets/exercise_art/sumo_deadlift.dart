import 'toolkit.dart';

/// Sumo deadlift — barbell, front view. Wide stance, narrow grip inside the
/// knees; hinge from floor to lockout.
ExerciseArt sumoDeadliftArt() => const ExerciseArt(
  view: ExerciseView.front,
  [
    // Bottom — wide stance, hips down, torso hinged forward.
    Pose(
      figure: Figure(
        pelvis: P(50, 70),
        torso: -70,
        arms: [Limb(115, 90), Limb(65, 90)], // arms angled in to narrow grip
        legs: [Limb(195, 85), Limb(-15, 95)], // legs splayed very wide
      ),
      barbells: [Barbell(hands: [0, 1], length: 16)],
    ),
    // Lockout — upright.
    Pose(
      figure: Figure(
        pelvis: P(50, 54),
        torso: -90,
        arms: [Limb(110, 90), Limb(70, 90)],
        legs: [Limb(195, 85), Limb(-15, 95)],
      ),
      barbells: [Barbell(hands: [0, 1], length: 16)],
    ),
  ],
);
