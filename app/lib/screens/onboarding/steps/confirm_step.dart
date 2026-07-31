/// Onboarding step 4: review the chosen program and starting weights.
library;

import 'package:flutter/material.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../../../logic/user_profile.dart';
import '../../../logic/weight_units.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/common/primary_button.dart';

class ConfirmStep extends StatelessWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final WeightUnit weightUnit;
  final String selectedEmoji;
  final String selectedColorHex;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final bool isSaving;

  const ConfirmStep({super.key, 
    required this.program,
    required this.controllers,
    required this.weightUnit,
    required this.selectedEmoji,
    required this.selectedColorHex,
    required this.onBack,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = profileColorFromHex(selectedColorHex);
    // Pick text colour that contrasts with the accent background.
    final onAccent =
        accent.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    final onboardingFields = program.stateSchema.fields
        .where((f) => f.onboardingField)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final suffix = weightUnitSuffix(weightUnit);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIRM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Do these look right?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Starting too heavy is the most common beginner mistake. You can change these later in settings.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coloured hero header
                Container(
                  color: accent,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        selectedEmoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              program.displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: onAccent,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              program.headline,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: onAccent.withValues(alpha: 0.7),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Weight rows
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (int i = 0; i < onboardingFields.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: cs.outline.withValues(alpha: 0.1),
                          ),
                        Builder(
                          builder: (context) {
                            final f = onboardingFields[i];
                            final text =
                                controllers[f.key]?.text.trim() ?? '';
                            final isWeight =
                                SettingsProvider.isWeightField(f);
                            final displayValue =
                                isWeight && text.isNotEmpty
                                    ? '$text $suffix'
                                    : text.isNotEmpty
                                    ? text
                                    : '—';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      f.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface.withValues(
                                          alpha: isWeight ? 0.85 : 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    displayValue,
                                    style: TextStyle(
                                      fontSize: isWeight ? 17 : 15,
                                      fontWeight: FontWeight.w900,
                                      color: isWeight
                                          ? accent
                                          : cs.onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                ],
              ),
            ),
          const Spacer(),
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
                child: PrimaryButton(
                  label: 'Start',
                  accent: accent,
                  loading: isSaving,
                  onPressed: onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
