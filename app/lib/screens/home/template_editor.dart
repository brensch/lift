/// The template editor: a name and an ordered exercise list. That is the
/// whole thing — sets, reps, rest and weight are prescribed, and per-
/// exercise adjustments live on the tracker (tap a row), so they apply in
/// every template that contains the exercise.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_picker.dart';

Future<void> showTemplateEditor(
  BuildContext context, {
  required WorkoutTemplate? template,
  required WorkoutProvider provider,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _TemplateEditorSheet(template: template),
    ),
  );
}

class _TemplateEditorSheet extends StatefulWidget {
  final WorkoutTemplate? template;
  const _TemplateEditorSheet({required this.template});

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late final TextEditingController _nameController;
  late List<Exercise> _exercises;
  bool _isSaving = false;

  bool get _isNew => widget.template == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.template?.name ?? '',
    );
    _exercises = List.of(widget.template?.exercises ?? const <Exercise>[]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _exercises.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final template = WorkoutTemplate()
        ..id = widget.template?.id ?? ''
        ..name = name
        ..exercises.addAll(_exercises);
      await context.read<WorkoutProvider>().saveTemplate(template);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addExercises() {
    showExercisePicker(
      context: context,
      trackers: context.read<WorkoutProvider>().trackers,
      isSelected: (e) => _exercises.contains(e),
      onToggle: (exercise, selected) {
        setState(() {
          if (selected) {
            if (!_exercises.contains(exercise)) _exercises.add(exercise);
          } else {
            _exercises.remove(exercise);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wp = context.watch<WorkoutProvider>();
    final unit = context.watch<SettingsProvider>().weightUnit;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.sheetColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: AppTheme.sheetHandle(context)),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isNew ? 'New template' : 'Edit template',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Name — e.g. Push, Legs, Tuesday',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(borderRadius: AppTheme.brSm),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: _exercises.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Add exercises. Tap one to adjust its weight or '
                      'sets — that adjustment follows the exercise '
                      'everywhere.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: _exercises.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final moved = _exercises.removeAt(oldIndex);
                        _exercises.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, index) {
                      final exercise = _exercises[index];
                      return _ExerciseRow(
                        key: ValueKey(exercise.value),
                        index: index,
                        exercise: exercise,
                        tracker: wp.trackerFor(exercise),
                        unit: unit,
                        onRemove: () =>
                            setState(() => _exercises.removeAt(index)),
                        onTap: () => _editTracker(exercise),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addExercises,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'ADD EXERCISES',
              style: TextStyle(fontWeight: FontWeight.w800),
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
                  : const Text(
                      'SAVE TEMPLATE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTracker(Exercise exercise) async {
    final wp = context.read<WorkoutProvider>();
    final unit = context.read<SettingsProvider>().weightUnit;
    final tracker = wp.trackerFor(exercise);
    if (tracker == null) return;
    await showTrackerSheet(context, tracker: tracker, unit: unit, provider: wp);
    if (mounted) setState(() {});
  }
}

class _ExerciseRow extends StatelessWidget {
  final int index;
  final Exercise exercise;
  final ExerciseTracker? tracker;
  final WeightUnit unit;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _ExerciseRow({
    super.key,
    required this.index,
    required this.exercise,
    required this.tracker,
    required this.unit,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = tracker;
    final detail = resolved == null
        ? ''
        : resolved.workingWeight > 0
        ? '${resolved.sets}×${resolved.repRangeLow}–${resolved.repRangeHigh}'
              ' @ ${formatWeight(resolved.workingWeight, unit, includeUnit: true)}'
        : '${resolved.sets}×${resolved.repRangeLow}–${resolved.repRangeHigh}';
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      dense: true,
      onTap: onTap,
      leading: ReorderableDragStartListener(
        index: index,
        child: Icon(
          Icons.drag_indicator,
          color: cs.onSurface.withValues(alpha: 0.4),
        ),
      ),
      title: Text(
        exerciseNames[exercise] ?? '?',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: detail.isEmpty
          ? null
          : Text(
              '$detail${(resolved?.overridden ?? false) ? '  · custom' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, size: 20),
        onPressed: onRemove,
      ),
    );
  }
}

// ── Tracker sheet ────────────────────────────────────────────────────────────

/// Adjust one exercise's weight, sets and rep range. Writes to the
/// tracker, so it applies everywhere the exercise appears — templates
/// hold no numbers.
Future<void> showTrackerSheet(
  BuildContext context, {
  required ExerciseTracker tracker,
  required WeightUnit unit,
  required WorkoutProvider provider,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _TrackerSheet(tracker: tracker, unit: unit),
    ),
  );
}

class _TrackerSheet extends StatefulWidget {
  final ExerciseTracker tracker;
  final WeightUnit unit;
  const _TrackerSheet({required this.tracker, required this.unit});

  @override
  State<_TrackerSheet> createState() => _TrackerSheetState();
}

class _TrackerSheetState extends State<_TrackerSheet> {
  late final TextEditingController _weightController;
  late int _sets;
  late int _repLow;
  late int _repHigh;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: formatWeight(widget.tracker.workingWeight, widget.unit),
    );
    _sets = widget.tracker.sets;
    _repLow = widget.tracker.repRangeLow;
    _repHigh = widget.tracker.repRangeHigh;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final display = double.tryParse(_weightController.text.trim()) ?? 0;
      final pounds = poundsFromDisplayWeight(display, widget.unit);
      await context.read<WorkoutProvider>().setExerciseTracker(
        exercise: widget.tracker.exercise,
        workingWeightLb: pounds,
        overrideSets: _sets,
        overrideRepLow: _repLow,
        overrideRepHigh: _repHigh,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = exerciseNames[widget.tracker.exercise] ?? '?';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.sheetColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: AppTheme.sheetHandle(context)),
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Changes here follow the exercise into every template.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Working weight',
              suffixText: weightUnitSuffix(widget.unit),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _Stepper(
            label: 'Sets',
            value: _sets,
            min: 1,
            max: 8,
            onChanged: (v) => setState(() => _sets = v),
          ),
          _Stepper(
            label: 'Rep range from',
            value: _repLow,
            min: 1,
            max: 30,
            onChanged: (v) => setState(() {
              _repLow = v;
              if (_repHigh < _repLow) _repHigh = _repLow;
            }),
          ),
          _Stepper(
            label: 'Rep range to',
            value: _repHigh,
            min: _repLow,
            max: 30,
            onChanged: (v) => setState(() => _repHigh = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'SAVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
