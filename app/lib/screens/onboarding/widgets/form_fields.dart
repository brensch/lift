/// Form inputs used across the onboarding steps: inline body-weight field, experience selector, stepper field, schema-driven state field input.
library;

import 'package:flutter/material.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../../../logic/weight_units.dart';
import '../../../providers/settings_provider.dart';
import '../onboarding_screen.dart';

class BodyWeightInlineField extends StatelessWidget {
  final TextEditingController controller;
  final WeightUnit weightUnit;
  final String hintText;
  final bool isImporting;

  const BodyWeightInlineField({super.key, 
    required this.controller,
    required this.weightUnit,
    required this.hintText,
    required this.isImporting,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Bodyweight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            if (isImporting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: weightUnitSuffix(weightUnit),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hintText,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: cs.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class ExperienceSelector extends StatelessWidget {
  final ExperienceLevel selected;
  final ValueChanged<ExperienceLevel> onSelect;

  const ExperienceSelector({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      (ExperienceLevel.cute, 'Cute'),
      (ExperienceLevel.beginner, 'Some'),
      (ExperienceLevel.intermediate, 'More'),
      (ExperienceLevel.expert, 'Lots'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Muscles',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final item in items) ...[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: item.$1 == ExperienceLevel.expert ? 0 : 8,
                  ),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(item.$2, textAlign: TextAlign.center),
                    ),
                    selected: selected == item.$1,
                    selectedColor: cs.primary.withValues(alpha: 0.14),
                    showCheckmark: false,
                    onSelected: (_) => onSelect(item.$1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class StepperField extends StatefulWidget {
  final TextEditingController controller;
  final double step;
  final double min;
  final double? max;
  final String? suffixText;

  const StepperField({super.key, 
    required this.controller,
    required this.step,
    required this.min,
    this.max,
    this.suffixText,
  });

  @override
  State<StepperField> createState() => StepperFieldState();
}

class StepperFieldState extends State<StepperField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _bump(double delta) {
    final current =
        double.tryParse(widget.controller.text.trim()) ?? widget.min;
    final decimals = widget.step % 1 == 0 ? 0 : 2;
    final next = (current + delta).clamp(
      widget.min,
      widget.max ?? double.infinity,
    );
    widget.controller.text = next.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        StepperButton(icon: Icons.remove, onTap: () => _bump(-widget.step)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixText: widget.suffixText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        StepperButton(icon: Icons.add, onTap: () => _bump(widget.step)),
      ],
    );
  }
}

class StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const StepperButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

/// Renders a single state field input: enum → choice chips, numeric → text field.
class StateFieldInput extends StatefulWidget {
  final TrainingProgramStateFieldSchema field;
  final TextEditingController controller;
  final WeightUnit weightUnit;

  const StateFieldInput({super.key, 
    required this.field,
    required this.controller,
    required this.weightUnit,
  });

  @override
  State<StateFieldInput> createState() => StateFieldInputState();
}

class StateFieldInputState extends State<StateFieldInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = widget.field;

    if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM &&
        f.enumOptions.isNotEmpty) {
      final current = widget.controller.text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (f.helpText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                f.helpText,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            children: f.enumOptions.map((opt) {
              return ChoiceChip(
                label: Text(opt.label.isNotEmpty ? opt.label : opt.value),
                selected: opt.value == current,
                onSelected: (_) =>
                    setState(() => widget.controller.text = opt.value),
              );
            }).toList(),
          ),
        ],
      );
    }

    final isNumeric =
        f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT ||
        f.kind == StateFieldKind.STATE_FIELD_KIND_INT;
    final unit = widget.weightUnit;
    final isWeightField = SettingsProvider.isWeightField(f);
    final suffix = isWeightField ? weightUnitSuffixPlural(unit) : null;
    final step = isWeightField
        ? barbellIncrement(unit)
        : (f.step > 0 ? f.step : 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.label,
                style: TextStyle(
                  fontWeight: isWeightField ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isWeightField ? 18 : 14,
                ),
              ),
              if (f.helpText.isNotEmpty && !isWeightField)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Text(
                    f.helpText,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 224,
          child: isNumeric
              ? StepperField(
                  controller: widget.controller,
                  step: step,
                  min: f.minValue,
                  max: f.maxValue > f.minValue ? f.maxValue : null,
                  suffixText: suffix,
                )
              : TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixText: suffix,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outline.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
