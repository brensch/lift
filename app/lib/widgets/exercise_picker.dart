import 'package:flutter/material.dart';

import '../gen/workout/v1/workout.pbenum.dart';
import '../logic/exercises.dart';
import 'exercise_graphic.dart';

/// Per-body-part accent colour, used for both the filter chips and the row tags.
Color bodyPartColor(BodyPart part) {
  switch (part) {
    case BodyPart.chest:
      return const Color(0xFF6BB6FF);
    case BodyPart.back:
      return const Color(0xFFE3C66B);
    case BodyPart.shoulders:
      return const Color(0xFFC79BFF);
    case BodyPart.arms:
      return const Color(0xFFFFB36B);
    case BodyPart.legs:
      return const Color(0xFF7CF2C0);
    case BodyPart.ass:
      return const Color(0xFFFF7EB6);
    case BodyPart.core:
      return const Color(0xFF6BE3E3);
  }
}

/// Opens the full-height exercise picker. Reflects the currently-selected
/// exercises via [isSelected] and reports add/remove through [onToggle] as the
/// user taps, so the host sheet updates live.
Future<void> showExercisePicker({
  required BuildContext context,
  required bool Function(Exercise) isSelected,
  required void Function(Exercise exercise, bool selected) onToggle,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExercisePickerSheet(
      isSelected: isSelected,
      onToggle: onToggle,
    ),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  final bool Function(Exercise) isSelected;
  final void Function(Exercise exercise, bool selected) onToggle;

  const _ExercisePickerSheet({required this.isSelected, required this.onToggle});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<Exercise> _selected = {};
  String _query = '';
  BodyPart? _filter; // null = All

  @override
  void initState() {
    super.initState();
    for (final info in exerciseCatalog) {
      if (widget.isSelected(info.exercise)) _selected.add(info.exercise);
    }
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

  List<ExerciseInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    return exerciseCatalog.where((info) {
      if (_filter != null && !info.bodyParts.contains(_filter)) return false;
      if (q.isEmpty) return true;
      return info.name.toLowerCase().contains(q);
    }).toList();
  }

  void _toggle(Exercise exercise) {
    final nowSelected = !_selected.contains(exercise);
    setState(() {
      if (nowSelected) {
        _selected.add(exercise);
      } else {
        _selected.remove(exercise);
      }
    });
    widget.onToggle(exercise, nowSelected);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // grab handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 12, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ADD EXERCISE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // search
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercises…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
                        color: bodyPartColor(part),
                        selected: _filter == part,
                        alwaysOutlined: part == BodyPart.ass,
                        onTap: () => setState(
                          () => _filter = _filter == part ? null : part,
                        ),
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
            ],
          ),
        );
      },
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
            borderRadius: BorderRadius.circular(20),
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
      borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(14),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                selected ? Icons.check : Icons.add,
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
    final color = bodyPartColor(part);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        bodyPartLabels[part]!.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
