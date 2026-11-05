/// The template editor, a page of its own: a name, whether it is in the
/// rotation the suggestion picks from, and an ordered exercise list. That
/// is the whole thing — sets, reps and weight are planned, each
/// row shows its next plan (the list planned as one workout in Home's
/// budget, so it reads what Home's card reads), and tapping one sets your
/// own numbers for the exercise (an override), which apply in every
/// template that contains it. Nothing is recorded until Save.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../gen/copy.dart';
import '../../logic/exercises.dart';
import '../../logic/plan_text.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/flat.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/exercise_picker.dart';
import '../../theme/app_icons.dart';
import '../../widgets/dialogs/workout_sheet.dart';

/// Edit [template] (null: a new one). [personalise] is Clone: Save makes a
/// library template the user's own, changed or not; backing out leaves it
/// following the library.
Future<void> showTemplateEditor(
  BuildContext context, {
  required WorkoutTemplate? template,
  required WorkoutProvider provider,
  bool personalise = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/template-editor'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: _TemplateEditorSheet(
          template: template,
          personalise: personalise,
        ),
      ),
    ),
  );
}

class _TemplateEditorSheet extends StatefulWidget {
  final WorkoutTemplate? template;
  final bool personalise;
  const _TemplateEditorSheet({
    required this.template,
    required this.personalise,
  });

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late final TextEditingController _nameController;
  late List<Exercise> _exercises;
  // A new workout starts as a reserve.
  late bool _inRotation;
  bool _isSaving = false;
  // The list on screen planned as one workout; null until the first plan.
  TemplatePlan? _plan;
  late final WorkoutProvider _provider;

  bool get _isNew => widget.template == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _exercises = List.of(widget.template?.exercises ?? const <Exercise>[]);
    _inRotation = widget.template?.inRotation ?? false;
    // A new budget, an override or a finished workout changes the plan.
    _provider = context.read<WorkoutProvider>()..addListener(_replan);
    _replan();
  }

  @override
  void dispose() {
    _provider.removeListener(_replan);
    _nameController.dispose();
    super.dispose();
  }

  /// Plan the list on screen, keeping the answer only if the list has not
  /// changed since.
  Future<void> _replan() async {
    final exercises = List.of(_exercises);
    if (exercises.isEmpty) {
      if (mounted) setState(() => _plan = null);
      return;
    }
    try {
      final plan = await _provider.planTemplate(exercises);
      if (mounted && listEquals(exercises, _exercises)) {
        setState(() => _plan = plan);
      }
    } catch (e) {
      debugPrint('Template plan failed: $e');
    }
  }

  /// [exercise]'s plan in this list; null until the list is planned.
  ExercisePlan? _planFor(Exercise exercise) {
    for (final plan in _plan?.plans ?? const <ExercisePlan>[]) {
      if (plan.decision.exercise == exercise) return plan;
    }
    return null;
  }

  /// Change the list and plan it again.
  void _setExercises(List<Exercise> exercises) {
    setState(() => _exercises = exercises);
    _replan();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _exercises.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final template = WorkoutTemplate()
        ..id = widget.template?.id ?? ''
        ..name = name
        ..inRotation = _inRotation
        ..exercises.addAll(_exercises);
      await context.read<WorkoutProvider>().saveTemplate(
        template,
        unlink: widget.personalise,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copy.templateEditor.saveFailed.replaceAll('{error}', '$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addExercises() {
    showExercisePicker(
      context: context,
      plans: context.read<WorkoutProvider>().plans,
      initialSelected: _exercises.toSet(),
      onSave: (selected) {
        // Keep the existing order for retained exercises; append the newly
        // picked ones in catalog order.
        _setExercises([
          ..._exercises.where(selected.contains),
          for (final info in exerciseCatalog)
            if (selected.contains(info.exercise) &&
                !_exercises.contains(info.exercise))
              info.exercise,
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;

    return Scaffold(
      appBar: AppBar(
        title: PageTitle(
          _isNew ? copy.templateEditor.newTitle : copy.templateEditor.editTitle,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: copy.templateEditor.nameHint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(borderRadius: context.tokens.brSm),
                ),
                style: TextStyle(
                  fontSize: context.tokens.size.body,
                  fontWeight: context.tokens.weight.bold,
                ),
                onChanged: (_) => setState(() {}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  copy.rotation.switchLabel,
                  style: TextStyle(
                    fontSize: context.tokens.size.body,
                    fontWeight: context.tokens.weight.bold,
                  ),
                ),
                subtitle: Text(
                  copy.rotation.switchHint,
                  style: TextStyle(
                    fontSize: context.tokens.size.small,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: _inRotation,
                onChanged: (v) => setState(() => _inRotation = v),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _exercises.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          copy.templateEditor.empty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: _exercises.length,
                        onReorderItem: (oldIndex, newIndex) {
                          // onReorderItem's newIndex is already adjusted
                          // for the removed item: no `newIndex -= 1`.
                          final next = List.of(_exercises);
                          final moved = next.removeAt(oldIndex);
                          next.insert(newIndex, moved);
                          _setExercises(next);
                        },
                        itemBuilder: (context, index) {
                          final exercise = _exercises[index];
                          return _ExerciseRow(
                            key: ValueKey(exercise.value),
                            index: index,
                            exercise: exercise,
                            plan: _planFor(exercise),
                            unit: unit,
                            onRemove: () => _setExercises(
                              List.of(_exercises)..removeAt(index),
                            ),
                            onTap: () => _editOverride(exercise),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _addExercises,
                icon: const Icon(AppIcons.add, size: 18),
                label: Text(
                  copy.templateEditor.addExercises,
                  style: TextStyle(fontWeight: context.tokens.weight.heavy),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed:
                      _nameController.text.trim().isEmpty || _exercises.isEmpty
                      ? null
                      : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          copy.templateEditor.save,
                          style: TextStyle(
                            fontWeight: context.tokens.weight.heavy,
                            fontSize: context.tokens.size.bodyLg,
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

  Future<void> _editOverride(Exercise exercise) async {
    final wp = context.read<WorkoutProvider>();
    final unit = context.read<SettingsProvider>().weightUnit;
    final plan = _planFor(exercise) ?? wp.planFor(exercise);
    if (plan == null) return;
    // The override refreshes Home, and the provider's notice plans again.
    await showOverrideSheet(context, plan: plan, unit: unit, provider: wp);
  }
}

class _ExerciseRow extends StatelessWidget {
  final int index;
  final Exercise exercise;
  final ExercisePlan? plan;
  final WeightUnit unit;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _ExerciseRow({
    super.key,
    required this.index,
    required this.exercise,
    required this.plan,
    required this.unit,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = plan;
    final detail = p == null
        ? ''
        : [
            planLine(p.decision, unit),
            if (p.overridden) copy.plan.override.custom,
            reasonShort(p.decision, unit),
          ].where((part) => part.isNotEmpty).join('  · ');
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      dense: true,
      onTap: onTap,
      leading: ReorderableDragStartListener(
        index: index,
        child: Icon(AppIcons.drag, color: cs.onSurface.withValues(alpha: 0.4)),
      ),
      title: Text(
        exerciseName(exercise),
        style: TextStyle(
          fontSize: context.tokens.size.body,
          fontWeight: context.tokens.weight.bold,
        ),
      ),
      subtitle: detail.isEmpty
          ? null
          : Text(detail, style: TextStyle(fontSize: context.tokens.size.small)),
      trailing: IconButton(
        icon: const Icon(AppIcons.removeCircle, size: 20),
        onPressed: onRemove,
      ),
    );
  }
}

// ── Override sheet ───────────────────────────────────────────────────────────

/// Set your own weight and reps (and optionally sets) for one exercise, or
/// hand it back to the plan. An override follows the exercise everywhere —
/// templates hold no numbers — and the plan carries on from it.
Future<void> showOverrideSheet(
  BuildContext context, {
  required ExercisePlan plan,
  required WeightUnit unit,
  required WorkoutProvider provider,
}) {
  return showWorkoutSheet(
    context,
    provider: provider,
    name: 'sheet/override',
    child: _OverrideSheet(plan: plan, unit: unit),
  );
}

class _OverrideSheet extends StatefulWidget {
  final ExercisePlan plan;
  final WeightUnit unit;
  const _OverrideSheet({required this.plan, required this.unit});

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  late final TextEditingController _weightController;
  late int _reps;
  late int _sets;
  // Off: the time budget decides the sets.
  bool _fixSets = false;
  bool _isSaving = false;

  ExerciseDecision get _decision => widget.plan.decision;
  bool get _bodyweight =>
      widget.plan.equipment == EquipmentKind.EQUIPMENT_KIND_BODYWEIGHT;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: formatWeight(_decision.weight, widget.unit),
    );
    _reps = _decision.reps > 0 ? _decision.reps : _decision.repLow;
    _sets = _decision.sets;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _write(Future<void> Function(WorkoutProvider wp) write) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await write(context.read<WorkoutProvider>());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copy.templateEditor.saveFailed.replaceAll('{error}', '$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // A loaded lift needs a weight: blank or 0 would plan it at nothing.
  bool get _canSave =>
      _bodyweight || (parseDisplayWeight(_weightController.text) ?? 0) > 0;

  Future<void> _save() {
    final display = parseDisplayWeight(_weightController.text) ?? 0;
    return _write(
      (wp) => wp.setOverride(
        exercise: _decision.exercise,
        weightLb: _bodyweight
            ? 0
            : poundsFromDisplayWeight(display, widget.unit),
        reps: _reps,
        sets: _fixSets ? _sets : null,
      ),
    );
  }

  Future<void> _remove() =>
      _write((wp) => wp.removeOverride(_decision.exercise));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = copy.plan.override;
    final name = exerciseName(_decision.exercise);
    final reasons = reasonLines(_decision, widget.unit);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.sheetColor(context),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      // Its own Material: the switch row paints on it, not under the panel.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AppTheme.sheetHandle(context, inset: 20)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: context.tokens.size.subtitle,
                      fontWeight: context.tokens.weight.heavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            // The next plan, and why.
            Text(
              planLine(_decision, widget.unit),
              style: TextStyle(
                fontSize: context.tokens.size.body,
                fontWeight: context.tokens.weight.bold,
              ),
            ),
            for (final line in reasons)
              Text(
                line,
                style: TextStyle(
                  fontSize: context.tokens.size.small,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              o.body,
              style: TextStyle(
                fontSize: context.tokens.size.small,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            if (!_bodyweight) ...[
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: o.weight,
                  suffixText: weightUnitSuffix(widget.unit),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],
            _Stepper(
              label: o.reps,
              value: _reps,
              min: 1,
              max: 30,
              onChanged: (v) => setState(() => _reps = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _fixSets ? o.sets : o.setsAuto,
                style: TextStyle(
                  fontSize: context.tokens.size.body,
                  fontWeight: context.tokens.weight.bold,
                ),
              ),
              value: _fixSets,
              onChanged: (v) => setState(() => _fixSets = v),
            ),
            if (_fixSets)
              _Stepper(
                label: o.sets,
                value: _sets,
                min: 1,
                max: 8,
                onChanged: (v) => setState(() => _sets = v),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _isSaving || !_canSave ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        o.save,
                        style: TextStyle(
                          fontWeight: context.tokens.weight.heavy,
                          fontSize: context.tokens.size.bodyLg,
                        ),
                      ),
              ),
            ),
            if (widget.plan.overridden) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSaving ? null : _remove,
                child: Text(o.remove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              fontWeight: context.tokens.weight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(AppIcons.removeCircle),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(AppIcons.addCircle),
        ),
      ],
    );
  }
}
