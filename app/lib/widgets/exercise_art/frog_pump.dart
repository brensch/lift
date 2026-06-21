import 'toolkit.dart';

/// Frog pump — bodyweight, side view. Supine on the floor, soles of feet
/// together, knees out; hips pump up.
ExerciseArt frogPumpArt() => const ExerciseArt([
  // Hips down — supine, knees flared and bent, feet together near hips.
  Pose(
    figure: Figure(
      pelvis: P(55, 64),
      torso: 178, // lying back, head to the left
      arms: [Limb(2, 2)], // arms flat on floor beside body
      legs: [
        Limb(-50, 130), // thigh flared up and forward, shin angles back to foot
        Limb(-46, 126),
      ],
    ),
  ),
  // Hips pumped up — pelvis rises, legs stay in frog position.
  Pose(
    figure: Figure(
      pelvis: P(55, 52),
      torso: 155, // torso tilts as shoulders stay on floor
      arms: [Limb(2, 2)],
      legs: [
        Limb(-30, 110),
        Limb(-26, 106),
      ],
    ),
  ),
]);
