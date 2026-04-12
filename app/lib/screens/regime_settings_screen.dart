import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import 'regime_info_screen.dart';
import '../widgets/top_level_back_scope.dart';

class RegimeSettingsScreen extends StatefulWidget {
  const RegimeSettingsScreen({super.key});

  @override
  State<RegimeSettingsScreen> createState() => _RegimeSettingsScreenState();
}

class _RegimeSettingsScreenState extends State<RegimeSettingsScreen> {
  RegimeType? _selectedRegimeType;
  final Map<String, TextEditingController> _controllers = {};
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureInitialized(SettingsProvider provider) {
    if (_initialized || !provider.loaded || provider.trainingPrograms.isEmpty) {
      return;
    }

    final currentState = provider.programState;
    final programs = provider.trainingPrograms;

    RegimeType initial;
    if (currentState != null) {
      initial = currentState.regimeType;
    } else {
      initial = programs.first.regimeType;
    }
    _selectedRegimeType = initial;

    final program = provider.trainingProgramFor(initial) ?? programs.first;
    _seedControllersForProgram(program, currentState);
    _initialized = true;
  }

  void _seedControllersForProgram(
    TrainingProgramDefinition program,
    TrainingProgramState? existingState,
  ) {
    for (final field in program.stateSchema.fields) {
      final next = _initialFieldText(
        field: field,
        program: program,
        existingState: existingState,
      );
      final current = _controllers[field.key];
      if (current == null) {
        _controllers[field.key] = TextEditingController(text: next);
      } else {
        current.text = next;
      }
    }
  }

  String _defaultFieldText(TrainingProgramStateFieldSchema field) {
    if (field.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT) {
      final provider = context.read<SettingsProvider>();
      final value = SettingsProvider.isWeightField(field)
          ? snapDisplayWeight(
              displayWeightFromPounds(field.minValue, provider.weightUnit),
              provider.weightUnit,
              poundStep: field.step,
              kilogramStep: SettingsProvider.displayStepForField(
                field,
                provider.weightUnit,
              ),
            )
          : field.minValue;
      if (value <= 0) return '';
      return value % 1 == 0
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    }
    if (field.kind == StateFieldKind.STATE_FIELD_KIND_INT) {
      return field.minValue.toInt().toString();
    }
    if (field.kind == StateFieldKind.STATE_FIELD_KIND_ENUM) {
      return field.enumOptions.isNotEmpty ? field.enumOptions.first.value : '';
    }
    return '';
  }

  String _initialFieldText({
    required TrainingProgramStateFieldSchema field,
    required TrainingProgramDefinition program,
    required TrainingProgramState? existingState,
  }) {
    final sameRegime = existingState?.regimeType == program.regimeType;
    if (sameRegime && (existingState?.fields[field.key]) != null) {
      return SettingsProvider.fieldValueToText(
        field,
        existingState!.fields[field.key],
        unit: context.read<SettingsProvider>().weightUnit,
      );
    }
    return _defaultFieldText(field);
  }

  String _normalizedFieldText(
    TrainingProgramStateFieldSchema field,
    TextEditingController? controller,
  ) {
    final raw = controller?.text.trim() ?? '';
    if (raw.isEmpty) return '';
    final parsed = SettingsProvider.fieldValueFromText(
      field,
      raw,
      unit: context.read<SettingsProvider>().weightUnit,
    );
    if (parsed == null) return raw;
    return SettingsProvider.fieldValueToText(
      field,
      parsed,
      unit: context.read<SettingsProvider>().weightUnit,
    );
  }

  bool _hasUnsavedChanges(
    SettingsProvider provider,
    TrainingProgramDefinition selectedProgram,
  ) {
    final savedState = provider.programState;
    if (savedState == null) return true;

    if (savedState.regimeType != selectedProgram.regimeType) return true;

    for (final field in selectedProgram.stateSchema.fields) {
      final current = _normalizedFieldText(field, _controllers[field.key]);
      final saved = SettingsProvider.fieldValueToText(
        field,
        savedState.fields[field.key],
        unit: provider.weightUnit,
      );
      if (current != saved) return true;
    }
    return false;
  }

  bool _isSwitchingProgram(
    SettingsProvider provider,
    TrainingProgramDefinition selectedProgram,
  ) {
    final savedState = provider.programState;
    if (savedState == null) return false;
    return savedState.regimeType != selectedProgram.regimeType;
  }

  Future<bool> _confirmProgramSwitch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch training program?'),
        content: const Text(
          'Are you sure you want to switch training program? Your progress on this one will still be here if you want to switch back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save(
    SettingsProvider provider,
    TrainingProgramDefinition program,
  ) async {
    if (_isSwitchingProgram(provider, program)) {
      final confirmed = await _confirmProgramSwitch();
      if (!confirmed || !mounted) return;
    }

    setState(() => _isSaving = true);
    try {
      final fields = <String, StateFieldValue>{};
      for (final f in program.stateSchema.fields) {
        final text = _controllers[f.key]?.text.trim() ?? '';
        final val = SettingsProvider.fieldValueFromText(
          f,
          text,
          unit: provider.weightUnit,
        );
        if (val != null) fields[f.key] = val;
      }

      final warnings = await provider.setActiveTrainingProgramState(
        regimeType: program.regimeType,
        fields: fields,
      );
      if (!mounted) return;

      if (warnings.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved with warnings: ${warnings.join('; ')}'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training program saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    _ensureInitialized(provider);

    if (!provider.loaded ||
        provider.trainingPrograms.isEmpty ||
        _selectedRegimeType == null) {
      return TopLevelBackScope(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
            ),
            title: const Text('Schplanner'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final programs = provider.trainingPrograms;
    final selected =
        provider.trainingProgramFor(_selectedRegimeType!) ?? programs.first;
    final hasUnsavedChanges = _hasUnsavedChanges(provider, selected);
    final cs = Theme.of(context).colorScheme;

    return TopLevelBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Schplanner'),
          centerTitle: false,
          actions: hasUnsavedChanges
              ? [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(provider, selected),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ]
              : const [],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              "Hello I am schplanner. My job is to schplan your workouts. I'll automatically progress your weight according to what i read about how to do it on the internet. My methods have cited sources and i don't use AI, just actual science and an algorithm.",
              style: TextStyle(fontSize: 14, height: 1.45, color: cs.tertiary),
            ),
            const SizedBox(height: 20),
            _SectionTitle('PROGRAM'),
            const SizedBox(height: 10),
            ...programs.map((program) {
              final isSelected = program.regimeType == selected.regimeType;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProgramTile(
                  program: program,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedRegimeType = program.regimeType;
                      _seedControllersForProgram(
                        program,
                        provider.programState,
                      );
                    });
                  },
                  onInfo: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RegimeInfoScreen(regimeType: program.regimeType),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            _StateFieldsEditor(
              program: selected,
              controllers: _controllers,
              colorScheme: cs,
              onFieldChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders all state fields for a program, grouped by section.
class _StateFieldsEditor extends StatefulWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final ColorScheme colorScheme;
  final VoidCallback onFieldChanged;

  const _StateFieldsEditor({
    required this.program,
    required this.controllers,
    required this.colorScheme,
    required this.onFieldChanged,
  });

  @override
  State<_StateFieldsEditor> createState() => _StateFieldsEditorState();
}

class _StateFieldsEditorState extends State<_StateFieldsEditor> {
  @override
  Widget build(BuildContext context) {
    final fields = [...widget.program.stateSchema.fields]
      ..sort((a, b) => a.order.compareTo(b.order));

    // Group fields by section
    final sections = <String, List<TrainingProgramStateFieldSchema>>{};
    for (final f in fields) {
      sections.putIfAbsent(f.section, () => []).add(f);
    }

    final widgets = <Widget>[];
    for (final entry in sections.entries) {
      widgets.add(_SectionTitle(entry.key.toUpperCase()));
      widgets.add(const SizedBox(height: 10));
      for (final f in entry.value) {
        if (widget.controllers.containsKey(f.key)) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _StateFieldInput(
                field: f,
                controller: widget.controllers[f.key]!,
                onChanged: () {
                  setState(() {});
                  widget.onFieldChanged();
                },
              ),
            ),
          );
        }
      }
      widgets.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _StateFieldInput extends StatelessWidget {
  final TrainingProgramStateFieldSchema field;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _StateFieldInput({
    required this.field,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = field;

    if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM &&
        f.enumOptions.isNotEmpty) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final current = controller.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
                    onSelected: (_) {
                      controller.text = opt.value;
                      onChanged();
                    },
                  );
                }).toList(),
              ),
            ],
          );
        },
      );
    }

    final isNumeric =
        f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT ||
        f.kind == StateFieldKind.STATE_FIELD_KIND_INT;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final suffix = SettingsProvider.isWeightField(f)
        ? weightUnitSuffixPlural(unit)
        : null;

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
        TextField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textAlign: TextAlign.right,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  final TrainingProgramDefinition program;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const _ProgramTile({
    required this.program,
    required this.isSelected,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  Text(
                    program.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onInfo,
              icon: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
