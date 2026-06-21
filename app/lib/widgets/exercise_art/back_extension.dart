import 'toolkit.dart';

/// Back extension — bodyweight, side view. Hips on pad, legs secured; torso hangs down → rises to horizontal.
/// pelvis=(50,48): pad supports the hips here.
/// Legs go upward-backward: Limb(-80,95) keeps shins near horizontal secured above.
/// Frame0: torso=65 (hanging down-right). Frame1: torso=0 (horizontal/raised).
ExerciseArt backExtensionArt() => const ExerciseArt([
  // Bottom — torso hanging down over the pad.
  Pose(
    figure: Figure(
      pelvis: P(38, 48),
      torso: 75,
      arms: [Limb(60, 60)],
      legs: [Limb(-75, 90), Limb(-77, 92)],
    ),
    props: [
      [P(22, 42), P(52, 62)], // angled hyperextension pad (hip support)
      [P(52, 62), P(52, 88)], // pad upright
      [P(35, 88), P(72, 88)], // base
      [P(60, 40), P(72, 40)], // ankle roller bar
    ],
  ),
  // Top — torso raised to horizontal.
  Pose(
    figure: Figure(
      pelvis: P(38, 48),
      torso: 0,
      arms: [Limb(180, 180)],
      legs: [Limb(-75, 90), Limb(-77, 92)],
    ),
    props: [
      [P(22, 42), P(52, 62)], // angled hyperextension pad (hip support)
      [P(52, 62), P(52, 88)], // pad upright
      [P(35, 88), P(72, 88)], // base
      [P(60, 40), P(72, 40)], // ankle roller bar
    ],
  ),
]);
