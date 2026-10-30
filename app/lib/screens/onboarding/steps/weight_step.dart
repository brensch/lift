/// Setup: bodyweight, for calories. Optional. Words in app/copy.yaml.
library;

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../../../logic/weight_units.dart';
import '../../../theme/theme_spec.dart';

class WeightStep extends StatelessWidget {
  final WeightUnit unit;
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const WeightStep({
    super.key,
    required this.unit,
    required this.controller,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.onboarding.weight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            style: TextStyle(
              fontSize: context.tokens.size.headline,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.body,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t.field,
              suffixText: weightUnitSuffix(unit),
              border: const OutlineInputBorder(),
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
                      style: TextStyle(fontWeight: context.tokens.weight.heavy),
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
