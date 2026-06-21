import 'toolkit.dart';

/// Curtsy lunge — bodyweight, side view. Stand → rear leg crosses behind and
/// to the side as you lunge down.
ExerciseArt curtsyLungeArt() => const ExerciseArt([
  // Stand.
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(90, 90)],
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
  ),
  // Curtsy lunge — front leg bends deep, rear leg crosses behind body.
  Pose(
    figure: Figure(
      pelvis: P(44, 68),
      torso: -84,
      arms: [Limb(90, 90)],
      legs: [
        Limb(45, 130), // front leg: knee well forward, deep bend
        Limb(150, 45), // rear leg: crosses behind, shin angled inward
      ],
    ),
  ),
]);
