import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen/workout/v1/workout.pb.dart' show ExerciseTracker;
import '../gen/workout/v1/workout.pbenum.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
import 'exercise_graphic.dart';
import '../theme/app_icons.dart';

/// Per-body-part accent colour, used for both the filter chips and the row tags.
Color bodyPartColor(BuildContext context, BodyPart part) =>
    context.tokens.bodyParts[part.index];

/// Opens the full-height exercise picker as a staged selection: the user
/// picks freely, nothing applies until SAVE (the big button at the
/// bottom), and dismissing it (swipe, tap outside, back) with changes asks
/// first. Presented on the root navigator so it covers the workout
/// bottom bar. [onSave] receives the final selection.
Future<void> showExercisePicker({
  required BuildContext context,
  required Set<Exercise> initialSelected,
  required void Function(Set<Exercise> selected) onSave,
  List<ExerciseTracker> trackers = const [],
  Set<Exercise> excluded = const {},
}) {
  return showModalBottomSheet(
    context: context,
    routeSettings: const RouteSettings(name: 'sheet/exercise-picker'),
    isScrollControlled: true,
    useRootNavigator: true,
    // Dismissal goes through the X so unsaved changes can ask first.
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExercisePickerSheet(
      initialSelected: initialSelected,
      onSave: onSave,
      trackers: trackers,
      excluded: excluded,
    ),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  final Set<Exercise> initialSelected;
  final void Function(Set<Exercise> selected) onSave;
  final List<ExerciseTracker> trackers;

  /// Not offered at all: in a workout, the exercises already in it (one
  /// exercise appears once).
  final Set<Exercise> excluded;

  const _ExercisePickerSheet({
    required this.initialSelected,
    required this.onSave,
    required this.trackers,
    required this.excluded,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  static const _machinesPrefKey = 'picker_show_machines';

  final TextEditingController _searchController = TextEditingController();
  final Set<Exercise> _selected = {};
  String _query = '';
  BodyPart? _filter; // null = All
  // Default to rack-and-dumbbell exercises: at the squat rack you should
  // not have to scroll past machines you would have to go hunting for.
  // The toggle persists.
  bool _showMachines = false;
  Map<int, EquipmentKind>? _equipment;

  @override
  void initState() {
    super.initState();
    if (widget.trackers.isNotEmpty) {
      _equipment = {
        for (final tracker in widget.trackers)
          tracker.exercise.value: tracker.equipment,
      };
    }
    unawaited(_loadMachinesPref());
    _selected.addAll(widget.initialSelected);
    _searchController.addListener(() {
      if (_query != _searchController.text) {
        setState(() => _query = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMachinesPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showMachines = prefs.getBool(_machinesPrefKey) ?? false);
  }

  Future<void> _setShowMachines(bool value) async {
    setState(() => _showMachines = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_machinesPrefKey, value);
  }

  bool _isMachineOrCable(Exercise exercise) {
    final kind = _equipment?[exercise.value];
    return kind == EquipmentKind.EQUIPMENT_KIND_MACHINE ||
        kind == EquipmentKind.EQUIPMENT_KIND_CABLE;
  }

  List<ExerciseInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    return exerciseCatalog.where((info) {
      if (widget.excluded.contains(info.exercise)) return false;
      if (_filter != null && !info.bodyParts.contains(_filter)) return false;
      // Searching overrides the equipment filter — a typed name always wins.
      if (_equipment != null &&
          !_showMachines &&
          q.isEmpty &&
          _isMachineOrCable(info.exercise) &&
          !_selected.contains(info.exercise)) {
        return false;
      }
      if (q.isEmpty) return true;
      return info.name.toLowerCase().contains(q);
    }).toList();
  }

  void _toggle(Exercise exercise) {
    setState(() {
      if (!_selected.remove(exercise)) {
        _selected.add(exercise);
      }
    });
  }

  bool get _dirty =>
      _selected.length != widget.initialSelected.length ||
      !_selected.containsAll(widget.initialSelected);

  void _save() {
    widget.onSave(Set.of(_selected));
    Navigator.pop(context);
  }

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Discard changes?',
          style: TextStyle(fontWeight: context.tokens.weight.heavy),
        ),
        content: const Text('Your selection has not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    // Leaving with changes asks first, however it's left.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(color: AppTheme.sheetColor(context)),
            child: Column(
              children: [
                // grab handle
                AppTheme.sheetHandle(context),
                // header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select exercises',
                          style: TextStyle(
                            fontSize: context.tokens.size.subtitle,
                            fontWeight: context.tokens.weight.heavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // search: on the same 20 inset as the filters and the list
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exercises…',
                      prefixIcon: const Icon(AppIcons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: context.tokens.brSm,
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                // body-part filters
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FilterChip(
                        label: 'ALL',
                        color: colorScheme.primary,
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final part in BodyPart.values)
                        _FilterChip(
                          label: bodyPartLabels[part]!.toUpperCase(),
                          color: bodyPartColor(context, part),
                          selected: _filter == part,
                          // In its colour, like the tags on the rows below.
                          alwaysOutlined: true,
                          onTap: () => setState(
                            () => _filter = _filter == part ? null : part,
                          ),
                        ),
                      if (_equipment != null)
                        _FilterChip(
                          label: _showMachines
                              ? 'HIDE MACHINES'
                              : 'SHOW MACHINES',
                          color: colorScheme.tertiary,
                          selected: _showMachines,
                          onTap: () => _setShowMachines(!_showMachines),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No exercises found',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: colorScheme.outline.withValues(alpha: 0.15),
                          ),
                          itemBuilder: (context, i) {
                            final info = filtered[i];
                            return _ExerciseRow(
                              info: info,
                              selected: _selected.contains(info.exercise),
                              onTap: () => _toggle(info.exercise),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _dirty ? _save : null,
                        child: Text(
                          'SAVE',
                          style: TextStyle(
                            fontSize: context.tokens.size.bodyLg,
                            fontWeight: context.tokens.weight.heavy,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool alwaysOutlined;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.alwaysOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? color
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: context.tokens.br(20),
            border: Border.all(
              color: alwaysOutlined && !selected
                  ? color
                  : colorScheme.outline.withValues(alpha: 0.4),
              width: alwaysOutlined && !selected ? 2 : 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: 0.5,
              color: selected
                  ? colorScheme.surface
                  : (alwaysOutlined ? color : colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _ExerciseRow({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: context.tokens.brMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // thumbnail tile
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
                borderRadius: context.tokens.brMd,
              ),
              alignment: Alignment.center,
              child: ExerciseGraphic(exercise: info.exercise, size: 60),
            ),
            const SizedBox(width: 14),
            // name + tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: TextStyle(
                      fontSize: context.tokens.size.bodyLg,
                      fontWeight: context.tokens.weight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final part in info.bodyParts) _Tag(part: part),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // add / added toggle
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                selected ? AppIcons.check : AppIcons.add,
                size: 20,
                color: selected ? colorScheme.surface : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final BodyPart part;

  const _Tag({required this.part});

  @override
  Widget build(BuildContext context) {
    final color = bodyPartColor(context, part);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: context.tokens.br(6),
      ),
      child: Text(
        bodyPartLabels[part]!.toUpperCase(),
        style: TextStyle(
          fontSize: context.tokens.size.small,
          fontWeight: context.tokens.weight.heavy,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
