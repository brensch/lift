import 'toolkit.dart';

/// Good morning — free weight, side view. Barbell on upper back/shoulders;
/// hip-hinge forward then back up. Near-straight legs throughout.
ExerciseArt goodMorningArt() => const ExerciseArt([
  // Standing tall — barbell on upper back/shoulders (arms reach back along bar).
  Pose(
    figure: Figure(
      pelvis: P(50, 52),
      torso: -90,
      arms: [Limb(180, 90)], // arm reaches back/up to bar on shoulders
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    barbells: [Barbell(hands: [0])],
  ),
  // Hinge forward — torso ~60° forward from vertical, legs near-straight.
  Pose(
    figure: Figure(
      pelvis: P(44, 55),
      torso: -30, // torso angled forward
      arms: [Limb(240, 150)], // arm follows to keep bar on shoulders
      legs: [Limb(88, 94), Limb(85, 97)], // slight knee bend
    ),
    barbells: [Barbell(hands: [0])],
  ),
]);
