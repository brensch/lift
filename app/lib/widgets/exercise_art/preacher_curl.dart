import 'toolkit.dart';

/// Preacher curl — dumbbell, side view. Arm rests over angled pad; forearm curls.
ExerciseArt preacherCurlArt() => const ExerciseArt([
  // Arm extended down the pad.
  Pose(
    figure: Figure(
      pelvis: P(42, 60),
      torso: -90,
      arms: [Limb(30, 30)], // upper arm angled forward-down onto the pad
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    props: [
      // Preacher pad: angled surface the upper arm rests on
      [P(52, 38), P(68, 62)], // pad face
      [P(68, 62), P(68, 82)], // pad support post
      [P(52, 82), P(68, 82)], // base
    ],
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Forearm curled up.
  Pose(
    figure: Figure(
      pelvis: P(42, 60),
      torso: -90,
      arms: [Limb(30, -50)], // upper arm stays on pad, forearm curls up
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    props: [
      [P(52, 38), P(68, 62)],
      [P(68, 62), P(68, 82)],
      [P(52, 82), P(68, 82)],
    ],
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
