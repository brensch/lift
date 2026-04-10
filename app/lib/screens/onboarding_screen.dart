import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import 'regime_info_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  RegimeType? _selectedRegimeType;
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  bool _initialized = false;

  void _goToStep(int nextStep) {
    if (_step == nextStep) return;
    setState(() => _step = nextStep);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFromCatalog(SettingsProvider provider) {
    if (_initialized || !provider.loaded || provider.trainingPrograms.isEmpty)
      return;
    final first = provider.trainingPrograms.first;
    _selectedRegimeType = first.regimeType;
    _seedFromSchema(first.stateSchema.fields);
    _initialized = true;
  }

  void _seedFromSchema(List<TrainingProgramStateFieldSchema> fields) {
    for (final f in fields) {
      if (!f.onboardingField) continue;
      _controllers.putIfAbsent(f.key, () => TextEditingController());
      _controllers[f.key]!.text = _defaultTextForField(f);
    }
  }

  String _defaultTextForField(TrainingProgramStateFieldSchema f) {
    if (f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT) {
      final provider = context.read<SettingsProvider>();
      final value = SettingsProvider.isWeightField(f)
          ? snapDisplayWeight(
              displayWeightFromPounds(f.minValue, provider.weightUnit),
              provider.weightUnit,
              poundStep: f.step,
              kilogramStep: SettingsProvider.displayStepForField(
                f,
                provider.weightUnit,
              ),
            )
          : f.minValue;
      if (value <= 0) return '';
      return value % 1 == 0
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    } else if (f.kind == StateFieldKind.STATE_FIELD_KIND_INT) {
      return f.minValue.toInt().toString();
    } else if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM) {
      return f.enumOptions.isNotEmpty ? f.enumOptions.first.value : '';
    }
    return '';
  }

  void _selectProgram(TrainingProgramDefinition p) {
    setState(() {
      _selectedRegimeType = p.regimeType;
      // Re-seed controllers for new program's onboarding fields
      final fields = p.stateSchema.fields
          .where((f) => f.onboardingField)
          .toList();
      for (final f in fields) {
        if (!_controllers.containsKey(f.key)) {
          _controllers[f.key] = TextEditingController(
            text: _defaultTextForField(f),
          );
        }
      }
    });
  }

  Future<void> _selectWeightUnit(
    SettingsProvider provider,
    WeightUnit unit,
  ) async {
    await provider.updateWeightUnit(unit);
    final selectedProgram = _selectedRegimeType == null
        ? null
        : provider.trainingProgramFor(_selectedRegimeType!);
    if (selectedProgram != null) {
      _seedFromSchema(selectedProgram.stateSchema.fields);
    }
  }

  Future<void> _save(
    SettingsProvider provider,
    TrainingProgramDefinition program,
  ) async {
    setState(() => _isSaving = true);
    try {
      final onboardingFields = program.stateSchema.fields
          .where((f) => f.onboardingField)
          .toList();

      final fields = <String, StateFieldValue>{};
      for (final f in onboardingFields) {
        final text = _controllers[f.key]?.text.trim() ?? '';
        final val = SettingsProvider.fieldValueFromText(
          f,
          text,
          unit: provider.weightUnit,
        );
        if (val != null) fields[f.key] = val;
      }

      await provider.setActiveTrainingProgramState(
        regimeType: program.regimeType,
        fields: fields,
        source: 'onboarding_init',
      );
      if (!mounted) return;
      context.go('/');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    _initFromCatalog(provider);

    if (!provider.loaded ||
        provider.trainingPrograms.isEmpty ||
        _selectedRegimeType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final programs = provider.trainingPrograms;
    final selected =
        provider.trainingProgramFor(_selectedRegimeType!) ?? programs.first;
    final cs = Theme.of(context).colorScheme;
    final progressAlignment = switch (_step) {
      0 => Alignment.centerLeft,
      1 => Alignment.center,
      _ => Alignment.centerRight,
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goToStep(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: SizedBox(
                  height: 5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      const gap = 8.0;
                      final segmentWidth = (totalWidth - (gap * 2)) / 3;
                      return Stack(
                        children: [
                          Row(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: gap),
                                Container(
                                  width: segmentWidth,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: cs.outline.withValues(alpha: 0.18),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: progressAlignment,
                            child: Container(
                              width: segmentWidth,
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(opacity: curved, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _step == 0
                        ? _UnitStep(
                            selectedUnit: provider.weightUnit,
                            onSelect: (unit) =>
                                _selectWeightUnit(provider, unit),
                            onNext: () => _goToStep(1),
                          )
                        : _step == 1
                        ? _ProgramStep(
                            programs: programs,
                            selectedType: selected.regimeType,
                            onSelect: _selectProgram,
                            onInfo: (p) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegimeInfoScreen(regimeType: p.regimeType),
                              ),
                            ),
                            onBack: () => _goToStep(0),
                            onNext: () => _goToStep(2),
                          )
                        : _ConfigStep(
                            program: selected,
                            controllers: _controllers,
                            onBack: () => _goToStep(1),
                            onSave: _isSaving
                                ? null
                                : () => _save(provider, selected),
                            isSaving: _isSaving,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitStep extends StatelessWidget {
  final WeightUnit selectedUnit;
  final Future<void> Function(WeightUnit unit) onSelect;
  final VoidCallback onNext;

  const _UnitStep({
    required this.selectedUnit,
    required this.onSelect,
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
          _UnitCard(
            title: 'Pounds',
            subtitle: 'Best for making you think you lift more because the number is larger.',
            badge: '🦅',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_LB,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_LB),
          ),
          const SizedBox(height: 10),
          _UnitCard(
            title: 'Kilograms',
            subtitle: 'Best for science and everywhere except America',
            badge: '🌍',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_KG,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_KG),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onNext,
              child: const Text(
                'NEXT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramStep extends StatelessWidget {
  final List<TrainingProgramDefinition> programs;
  final RegimeType selectedType;
  final void Function(TrainingProgramDefinition) onSelect;
  final void Function(TrainingProgramDefinition) onInfo;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _ProgramStep({
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
                return _ProgramCard(
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

class _ConfigStep extends StatelessWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final bool isSaving;

  const _ConfigStep({
    required this.program,
    required this.controllers,
    required this.onBack,
    required this.onSave,
    required this.isSaving,
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
                'Set your starting weights',
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
              for (final f in onboardingFields)
                if (controllers.containsKey(f.key))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StateFieldInput(
                      field: f,
                      controller: controllers[f.key]!,
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
                    onPressed: onSave,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'START',
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

/// Renders a single state field input: enum → choice chips, numeric → text field.
class _StateFieldInput extends StatefulWidget {
  final TrainingProgramStateFieldSchema field;
  final TextEditingController controller;

  const _StateFieldInput({required this.field, required this.controller});

  @override
  State<_StateFieldInput> createState() => _StateFieldInputState();
}

class _StateFieldInputState extends State<_StateFieldInput> {
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
    final unit = context.watch<SettingsProvider>().weightUnit;
    final isWeightField = SettingsProvider.isWeightField(f);
    final suffix = isWeightField ? weightUnitSuffixPlural(unit) : null;

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
          width: 136,
          child: TextField(
            controller: widget.controller,
            keyboardType: isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
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

class _ProgramCard extends StatelessWidget {
  final TrainingProgramDefinition program;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const _ProgramCard({
    required this.program,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: 2,
                  ),
                  color: selected ? cs.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          program.headline,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        if (program.hasAtAGlance()) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _PreviewPill(
                                emoji: '📅',
                                text: program.atAGlance.daysPerWeek,
                              ),
                              _PreviewPill(
                                emoji: '🎯',
                                text: program.atAGlance.bestFor,
                              ),
                              _PreviewPill(
                                emoji: '⏱️',
                                text: program.atAGlance.averageSessionTime,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: -1,
                    right: 0,
                    child: IconButton(
                      onPressed: onInfo,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const _UnitCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Text(
                badge,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: selected ? cs.primary : Colors.transparent,
              ),
              child: selected
                  ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String emoji;
  final String text;
  const _PreviewPill({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$emoji $text',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
