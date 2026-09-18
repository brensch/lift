/// Setup: how strong are you, chick to gorilla. The lifts underneath show
/// the first working weights that setting gives, in the user's unit,
/// snapped to what fits on a bar. Words in app/copy.yaml.
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
  final double bodyweightKg; // 0 = not given
  final ValueChanged<double> onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const StrengthStep({
    super.key,
    required this.unit,
    required this.strength,
    required this.bodyweightKg,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.onboarding.strength;
    final weights = {
      for (final (ex, lb) in startingWeightsLb(
        bodyweightKg: bodyweightKg,
        strength: strength,
        unit: unit,
      ))
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
          const SizedBox(height: 28),
          Row(
            children: [
              const Text('🐣', style: TextStyle(fontSize: 34)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                    ),
                  ),
                  child: Slider(value: strength, onChanged: onChanged),
                ),
              ),
              const Text('🦍', style: TextStyle(fontSize: 34)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                for (final (ex, key) in _shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            labels[key] ?? key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          formatWeight(
                            weights[ex] ?? 0,
                            unit,
                            includeUnit: true,
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.note,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
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
