/// Onboarding step 1: choose pounds or kilograms.
library;

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import 'dart:async';
import '../../../gen/workout/v1/settings.pb.dart';
import '../widgets/selection_cards.dart';

class UnitStep extends StatelessWidget {
  final WeightUnit selectedUnit;
  final Future<void> Function(WeightUnit unit) onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const UnitStep({
    super.key,
    required this.selectedUnit,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.onboarding.unit.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            copy.onboarding.unit.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          UnitCard(
            title: copy.onboarding.unit.pounds,
            subtitle: copy.onboarding.unit.poundsBody,
            badge: '🦅',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_LB,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_LB),
          ),
          const SizedBox(height: 10),
          UnitCard(
            title: copy.onboarding.unit.kilograms,
            subtitle: copy.onboarding.unit.kilogramsBody,
            badge: '🌍',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_KG,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_KG),
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
