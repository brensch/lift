/// Onboarding step 1: choose pounds or kilograms.
library;

import 'package:flutter/material.dart';
import 'dart:async';
import '../../../gen/workout/v1/settings.pb.dart';
import '../widgets/selection_cards.dart';

class UnitStep extends StatelessWidget {
  final WeightUnit selectedUnit;
  final Future<void> Function(WeightUnit unit) onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const UnitStep({super.key, 
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
            'CHOOSE YOUR UNITS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What plates are you lifting with?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Ie are you in America',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          UnitCard(
            title: 'Pounds',
            subtitle:
                'Best for making you think you lift more because the number is larger.',
            badge: '🦅',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_LB,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_LB),
          ),
          const SizedBox(height: 10),
          UnitCard(
            title: 'Kilograms',
            subtitle: 'Best for science and everywhere except America',
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
                    child: const Text('BACK'),
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
                    child: const Text(
                      'NEXT',
                      style: TextStyle(fontWeight: FontWeight.w900),
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
