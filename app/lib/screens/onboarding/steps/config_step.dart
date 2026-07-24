/// Onboarding step 3: program configuration, rendered from the regime's state schema (onboarding_field = true fields).
library;

import 'package:flutter/material.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../onboarding_screen.dart';
import '../widgets/form_fields.dart';

class ConfigStep extends StatelessWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final TextEditingController bodyWeightController;
  final WeightUnit weightUnit;
  final ExperienceLevel experienceLevel;
  final String bodyWeightHint;
  final bool isImportingBodyWeight;
  final ValueChanged<ExperienceLevel> onSelectExperience;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const ConfigStep({super.key, 
    required this.program,
    required this.controllers,
    required this.bodyWeightController,
    required this.weightUnit,
    required this.experienceLevel,
    required this.bodyWeightHint,
    required this.isImportingBodyWeight,
    required this.onSelectExperience,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onboardingFields =
        program.stateSchema.fields.where((f) => f.onboardingField).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(
                'STARTING WEIGHTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: cs.tertiary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose starting weights',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${program.displayName} · ${program.headline}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                program.summary,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
              BodyWeightInlineField(
                controller: bodyWeightController,
                weightUnit: weightUnit,
                hintText: bodyWeightHint,
                isImporting: isImportingBodyWeight,
              ),
              const SizedBox(height: 16),
              ExperienceSelector(
                selected: experienceLevel,
                onSelect: onSelectExperience,
              ),
              const SizedBox(height: 12),
              Text(
                'These defaults are calculated from your bodyweight and self proclaimed muscle size.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 18),
              for (final f in onboardingFields)
                if (controllers.containsKey(f.key))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StateFieldInput(
                      field: f,
                      controller: controllers[f.key]!,
                      weightUnit: weightUnit,
                    ),
                  ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
        ),
      ],
    );
  }
}
