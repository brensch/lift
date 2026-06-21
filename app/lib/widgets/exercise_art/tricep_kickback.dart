import 'toolkit.dart';

/// Tricep kickback — dumbbell, side view. Torso hinged ~45° forward; upper arm
/// pinned horizontal (pointing back); forearm extends from bent to straight behind.
ExerciseArt tricepKickbackArt() => const ExerciseArt([
  // Forearm bent (start position — dumbbell near torso).
  Pose(
    figure: Figure(
      pelvis: P(46, 58),
      torso: -45, // hinged forward ~45°
      arms: [Limb(180, 90)], // upper arm horizontal back, forearm hanging down
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  // Forearm extended back (lockout — arm fully straight behind).
  Pose(
    figure: Figure(
      pelvis: P(46, 58),
      torso: -45,
      arms: [Limb(180, 180)], // upper arm horizontal back, forearm also extends back
      legs: [Limb(91, 91), Limb(89, 89)],
    ),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
