import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../providers/settings_provider.dart';
import 'regime_info_screen.dart';

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
    if (_initialized || !provider.loaded || provider.trainingPrograms.isEmpty) return;
    final config = provider.workoutConfig;
    final programs = provider.trainingPrograms;
    final preferred = config != null
        ? provider.trainingProgramFor(config.regimeType)
        : null;
    final selected = preferred ?? programs.first;
    _selectedRegimeType = selected.regimeType;
    _seedControllersForProgram(selected, config);
    _initialized = true;
  }

  void _seedControllersForProgram(
    TrainingProgramDefinition program,
    UserWorkoutConfig? existing,
  ) {
    for (final field in program.configFields) {
      final current = _controllers[field.key];
      String next;
      switch (field.binding) {
        case TrainingProgramFieldBinding.TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK:
          final days = (existing != null && existing.regimeType == program.regimeType && existing.daysPerWeek > 0)
              ? existing.daysPerWeek
              : (field.defaultInt32 > 0 ? field.defaultInt32 : 0);
          next = '$days';
          break;
        case TrainingProgramFieldBinding.TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX:
          final existingVal = (existing != null && existing.regimeType == program.regimeType)
              ? existing.oneRepMaxes[field.exerciseId]
              : null;
          final val = (existingVal != null && existingVal > 0)
              ? existingVal
              : field.defaultFloat;
          next = val > 0 ? val.toStringAsFixed(0) : '';
          break;
        default:
          next = field.kind == TrainingProgramFieldKind.TRAINING_PROGRAM_FIELD_KIND_INT32
              ? '${field.defaultInt32}'
              : field.kind == TrainingProgramFieldKind.TRAINING_PROGRAM_FIELD_KIND_FLOAT
                  ? (field.defaultFloat > 0 ? field.defaultFloat.toStringAsFixed(0) : '')
                  : (field.defaultBool ? 'true' : 'false');
      }
      if (current == null) {
        _controllers[field.key] = TextEditingController(text: next);
      } else {
        current.text = next;
      }
    }
  }

  Future<void> _save(SettingsProvider provider, TrainingProgramDefinition program) async {
    setState(() => _isSaving = true);
    try {
      final oneRepMaxes = <int, double>{};
      int daysPerWeek = 0;
      for (final field in program.configFields) {
        final text = _controllers[field.key]?.text.trim() ?? '';
        if (field.binding == TrainingProgramFieldBinding.TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK) {
          final parsed = int.tryParse(text);
          if (parsed != null && parsed > 0) daysPerWeek = parsed;
        } else if (field.binding == TrainingProgramFieldBinding.TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX) {
          final parsed = double.tryParse(text);
          if (parsed != null && parsed > 0 && field.exerciseId > 0) {
            oneRepMaxes[field.exerciseId] = parsed;
          }
        }
      }
      if (daysPerWeek <= 0) {
        daysPerWeek = 3;
      }

      final existing = provider.workoutConfig;
      final sameRegime = existing?.regimeType == program.regimeType;
      final config = UserWorkoutConfig(
        regimeType: program.regimeType,
        daysPerWeek: daysPerWeek,
        oneRepMaxes: oneRepMaxes.entries.map((e) => MapEntry(e.key, e.value)),
        regimeStateJson: sameRegime ? (existing?.regimeStateJson ?? '{}') : '{}',
      );

      await provider.updateWorkoutConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training program saved.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    _ensureInitialized(provider);

    if (!provider.loaded || provider.trainingPrograms.isEmpty || _selectedRegimeType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training Program')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final programs = provider.trainingPrograms;
    final selected = provider.trainingProgramFor(_selectedRegimeType!) ?? programs.first;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Program'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _save(provider, selected),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
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
                    _seedControllersForProgram(program, provider.workoutConfig);
                  });
                },
                onInfo: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegimeInfoScreen(regimeType: program.regimeType),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          _DynamicConfigFields(
            program: selected,
            controllers: _controllers,
            colorScheme: cs,
          ),
        ],
      ),
    );
  }
}

class _DynamicConfigFields extends StatelessWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final ColorScheme colorScheme;

  const _DynamicConfigFields({
    required this.program,
    required this.controllers,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final dayFields = program.configFields
        .where((f) =>
            f.binding ==
                TrainingProgramFieldBinding
                    .TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK &&
            !_isFixedDaysField(f))
        .toList();
    final otherFields = program.configFields
        .where((f) =>
            f.binding !=
                TrainingProgramFieldBinding
                    .TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK &&
            !_isHiddenFixedField(f))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dayFields.isNotEmpty) ...[
          _SectionTitle('DAYS PER WEEK'),
          const SizedBox(height: 10),
          ...dayFields.map((f) => _FieldInput(field: f, controller: controllers[f.key]!)),
          const SizedBox(height: 20),
        ],
        if (otherFields.isNotEmpty) ...[
          _SectionTitle('PROGRAM FIELDS'),
          const SizedBox(height: 4),
          Text(
            'Adjust your training setup for this program.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 12),
          ...otherFields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _FieldInput(field: f, controller: controllers[f.key]!),
            ),
          ),
        ],
      ],
    );
  }

  bool _isHiddenFixedField(TrainingProgramConfigField field) {
    if (field.binding !=
        TrainingProgramFieldBinding.TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK) {
      return false;
    }
    return _isFixedDaysField(field);
  }

  bool _isFixedDaysField(TrainingProgramConfigField field) {
    return field.intChoices.length <= 1;
  }
}

class _FieldInput extends StatelessWidget {
  final TrainingProgramConfigField field;
  final TextEditingController controller;

  const _FieldInput({required this.field, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasChoices = field.intChoices.isNotEmpty &&
        field.kind == TrainingProgramFieldKind.TRAINING_PROGRAM_FIELD_KIND_INT32;
    if (hasChoices) {
      final current = int.tryParse(controller.text) ?? field.defaultInt32;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (field.helpText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(field.helpText,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
            ),
          Wrap(
            spacing: 8,
            children: field.intChoices.map((choice) {
              final selected = choice.value == current;
              final label = choice.label.isNotEmpty ? choice.label : '${choice.value}';
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => controller.text = '${choice.value}',
              );
            }).toList(),
          ),
        ],
      );
    }

    final suffix = field.binding == TrainingProgramFieldBinding.TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX
        ? 'lbs'
        : null;
    final numeric = field.kind != TrainingProgramFieldKind.TRAINING_PROGRAM_FIELD_KIND_BOOL;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (field.helpText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(field.helpText,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
          ),
        TextField(
          controller: controller,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          textAlign: TextAlign.right,
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
          color: isSelected ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainerLowest,
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
                border: Border.all(color: isSelected ? cs.primary : cs.outline, width: 2),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected ? Icon(Icons.check, size: 10, color: cs.onPrimary) : null,
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
              icon: Icon(Icons.info_outline_rounded, size: 18, color: cs.primary.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
