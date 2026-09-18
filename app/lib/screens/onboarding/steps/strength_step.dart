/// Setup: how huge are you. A vertical slider on the right, weak at the
/// bottom and huge at the top; on the left the creature you currently
/// are and the first working weights that setting gives, snapped to what
/// fits on a bar in the user's unit. Words and creatures in app/copy.yaml.
library;

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../../../gen/workout/v1/workout.pb.dart';
import '../../../logic/starting_weights.dart';
import '../../../logic/weight_units.dart';

class StrengthStep extends StatelessWidget {
  final WeightUnit unit;
  final double strength; // 0 chick .. 1 gorilla
  final ValueChanged<double> onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const StrengthStep({
    super.key,
    required this.unit,
    required this.strength,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  static const _shown = [
    (Exercise.EXERCISE_SQUAT, 'squat'),
    (Exercise.EXERCISE_BENCH_PRESS, 'bench_press'),
    (Exercise.EXERCISE_DEADLIFT, 'deadlift'),
    (Exercise.EXERCISE_OVERHEAD_PRESS, 'overhead_press'),
  ];

  /// The creature for [strength]: the list in copy.yaml, chick first.
  static String creatureFor(double strength) {
    final list = copy.onboarding.strength.emojis;
    final i = (strength.clamp(0.0, 1.0) * (list.length - 1)).round();
    return list[i];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.onboarding.strength;
    final weights = {
      for (final (ex, lb) in startingWeightsLb(strength: strength, unit: unit))
        ex: lb,
    };
    final labels = {for (final l in t.lifts) l.id: l.label};

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            t.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: the creature, then the numbers.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creatureFor(strength),
                        style: const TextStyle(fontSize: 72, height: 1.1),
                      ),
                      const SizedBox(height: 12),
                      for (final (ex, key) in _shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labels[key] ?? key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                              Text(
                                formatWeight(
                                  weights[ex] ?? 0,
                                  unit,
                                  includeUnit: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        t.note,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right: the scale, huge at the top.
                Column(
                  children: [
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 10,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 16,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 26,
                            ),
                          ),
                          child: Slider(value: strength, onChanged: onChanged),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: Text(copy.onboarding.back),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: onNext,
                    child: Text(
                      copy.onboarding.next,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
