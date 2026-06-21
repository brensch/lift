import 'toolkit.dart';

/// Seated calf raise — MACHINE (grey), side view. Seated, knees bent ~90°;
/// heels drop then raise (plantar flexion).
ExerciseArt seatedCalfRaiseArt() => const ExerciseArt(
  machine: true,
  [
    // Heels dropped — full dorsiflexion (heels back, toes up).
    Pose(
      figure: Figure(
        pelvis: P(32, 56),
        torso: -90,
        arms: [Limb(10, 90)], // hand resting on pad
        legs: [Limb(1, 115), Limb(3, 113)], // thighs horizontal, shins angled well past vertical — heels back
      ),
      props: [
        [P(10, 44), P(10, 80)], // seat back
        [P(10, 62), P(48, 62)], // seat
        [P(20, 50), P(50, 50)], // knee pad
        [P(48, 62), P(48, 80)], // seat front leg
        [P(10, 80), P(52, 80)], // base
      ],
    ),
    // Heels raised — plantar flexion (toes pressing down, heels lifted high).
    Pose(
      figure: Figure(
        pelvis: P(32, 56),
        torso: -90,
        arms: [Limb(10, 90)],
        legs: [Limb(1, 60), Limb(3, 62)], // shins well forward of vertical — heels high
      ),
      props: [
        [P(10, 44), P(10, 80)],
        [P(10, 62), P(48, 62)],
        [P(20, 50), P(50, 50)],
        [P(48, 62), P(48, 80)],
        [P(10, 80), P(52, 80)],
      ],
    ),
  ],
);
