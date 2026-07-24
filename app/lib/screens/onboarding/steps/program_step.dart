/// Onboarding step 2: choose a training program from the catalog.
library;

import 'package:flutter/material.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../widgets/selection_cards.dart';

class ProgramStep extends StatelessWidget {
  final List<TrainingProgramDefinition> programs;
  final RegimeType selectedType;
  final void Function(TrainingProgramDefinition) onSelect;
  final void Function(TrainingProgramDefinition) onInfo;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const ProgramStep({super.key, 
    required this.programs,
    required this.selectedType,
    required this.onSelect,
    required this.onInfo,
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
            'CHOOSE YOUR PROGRAM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How do you train?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "Each program builds up the weight you can lift over time using different strategies. Pick one based on how much time you spend in the gym, how experienced you are, and/or vibes.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: programs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = programs[i];
                final selected = p.regimeType == selectedType;
                return ProgramCard(
                  program: p,
                  selected: selected,
                  onTap: () => onSelect(p),
                  onInfo: () => onInfo(p),
                );
              },
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
