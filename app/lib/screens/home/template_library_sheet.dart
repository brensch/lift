/// The Manage sheet ("Your workouts"): the rotation check at the top (a
/// line, the bars of one lap of the rotation as each muscle's share of
/// the most-trained one, and what is wrong with it); then one draggable
/// list of the rotation and the reserves, each row a drag handle, the name
/// and lifts, and delete; a drag reorders
/// within a section or moves a workout across into the other. Below it,
/// Add: the ready-made plans, one tap each, then the library workouts the
/// user does not have yet, each added to the rotation with +. A reserve or
/// a library row says which muscles it would add that the rotation
/// trains none of. Tapping one of the user's workouts opens it in the
/// editor.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart' show MuscleGroup;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/rotation_text.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/flat.dart';
import 'home_screen.dart' show VolumeCard;
import 'template_editor.dart';
import '../../widgets/template_row.dart';
import '../../theme/app_icons.dart';
import '../../widgets/dialogs/workout_sheet.dart';

Future<void> showTemplateLibrary(
  BuildContext context, {
  required WorkoutProvider provider,
}) {
  return showWorkoutSheet(
    context,
    provider: provider,
    name: 'sheet/template-library',
    child: const _LibrarySheet(),
  );
}

class _LibrarySheet extends StatefulWidget {
  const _LibrarySheet();

  @override
  State<_LibrarySheet> createState() => _LibrarySheetState();
}

/// One entry of the sheet's draggable list: a section's heading, a
/// workout of the user's, or the line an empty section shows to drop on.
sealed class _Item {
  const _Item();
  Key get key;
}

class _SectionItem extends _Item {
  final bool rotation;
  const _SectionItem(this.rotation);
  @override
  Key get key => ValueKey('section-$rotation');
}

class _EmptyItem extends _Item {
  final bool rotation;
  const _EmptyItem(this.rotation);
  @override
  Key get key => ValueKey('empty-$rotation');
}

class _MineItem extends _Item {
  final WorkoutTemplate template;
  const _MineItem(this.template);
  @override
  Key get key => ValueKey(template.id);
}

/// The draggable list: the rotation's heading, its workouts (or the drop
/// line), then the reserves' heading and theirs.
List<_Item> _sheetItems(
  List<WorkoutTemplate> rotation,
  List<WorkoutTemplate> reserves,
) => [
  const _SectionItem(true),
  if (rotation.isEmpty) const _EmptyItem(true),
  for (final t in rotation) _MineItem(t),
  const _SectionItem(false),
  if (reserves.isEmpty) const _EmptyItem(false),
  for (final t in reserves) _MineItem(t),
];

/// The list after a drag: every workout above the reserves' heading is in
/// the rotation (one dropped above the rotation's heading too), the rest
/// are reserves, each in the order shown.
({List<WorkoutTemplate> rotation, List<WorkoutTemplate> reserves}) _splitItems(
  List<_Item> items,
) {
  final rotation = <WorkoutTemplate>[];
  final reserves = <WorkoutTemplate>[];
  var inReserves = false;
  for (final item in items) {
    switch (item) {
      case _SectionItem(rotation: false):
        inReserves = true;
      case _MineItem(:final template):
        (inReserves ? reserves : rotation).add(template);
      default:
        break;
    }
  }
  return (rotation: rotation, reserves: reserves);
}

class _LibrarySheetState extends State<_LibrarySheet> {
  late Future<ListTemplateLibraryResponse> _library;
  final Set<String> _busy = {};

  /// A drag's result, shown until the core's answer replaces it.
  ({List<WorkoutTemplate> rotation, List<WorkoutTemplate> reserves})? _dragged;

  @override
  void initState() {
    super.initState();
    _library = context.read<WorkoutProvider>().service.templateLibrary();
  }

  /// Run [action] for [id], one at a time, saying so if it fails.
  Future<void> _run(String id, Future<void> Function() action) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _edit(WorkoutTemplate template) {
    final wp = context.read<WorkoutProvider>();
    Navigator.pop(context);
    showTemplateEditor(context, template: template, provider: wp);
  }

  /// A drag in the list: one reorder that also says where the rotation
  /// ends.
  Future<void> _reorder(List<_Item> items, int from, int to) async {
    final next = List.of(items);
    final moved = next.removeAt(from);
    if (moved is! _MineItem) return;
    next.insert(to, moved);
    final split = _splitItems(next);
    setState(() => _dragged = split);
    final wp = context.read<WorkoutProvider>();
    await _run(
      '__order__',
      () => wp.reorderTemplates([
        for (final t in [...split.rotation, ...split.reserves]) t.id,
      ], rotationCount: split.rotation.length),
    );
    if (mounted) setState(() => _dragged = null);
  }

  /// A library workout, into the rotation.
  Future<void> _add(LibraryTemplate entry) {
    final wp = context.read<WorkoutProvider>();
    return _run(
      entry.id,
      () => wp.addLibraryTemplates([entry.id], inRotation: true),
    );
  }

  /// A ready-made plan as the rotation.
  Future<void> _apply(LibraryPlan plan) {
    final wp = context.read<WorkoutProvider>();
    return _run('plan:${plan.id}', () => wp.applyLibraryPlan(plan.id));
  }

  /// A library workout goes straight (it can be added again); one of the
  /// user's own is asked about first.
  Future<void> _remove(WorkoutTemplate template) async {
    final wp = context.read<WorkoutProvider>();
    if (!template.coupled) {
      final t = copy.library;
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${t.delete} ${template.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.delete),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    await _run(template.id, () => wp.deleteTemplate(template.id));
  }

  /// One entry of the draggable list. Only a workout has a handle; a
  /// reserve says what it would add.
  Widget _item(_Item item, int index, Map<String, List<MuscleGroup>> adds) {
    final l = copy.library;
    final cs = Theme.of(context).colorScheme;
    return switch (item) {
      _SectionItem(:final rotation) => _Heading(
        key: item.key,
        rotation ? l.rotationHeading : l.reservesHeading,
        description: rotation ? l.rotationDescription : l.reservesDescription,
      ),
      _EmptyItem() => _EmptyLine(key: item.key, l.dropHere),
      _MineItem(:final template) => TemplateRow(
        key: item.key,
        name: template.name,
        exercises: template.exercises,
        personal: !template.coupled,
        showLifts: true,
        expandable: false,
        note: additionLine(adds[template.id] ?? const []),
        onTap: _busy.contains(template.id) ? null : () => _edit(template),
        leading: ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(AppIcons.drag, color: context.tokens.muted),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.delete,
            visualDensity: VisualDensity.compact,
            onPressed: _busy.contains(template.id)
                ? null
                : () => _remove(template),
            icon: Icon(AppIcons.delete, size: 20, color: cs.error),
          ),
        ],
      ),
    };
  }

  /// Below the list: the ready-made plans (the one the rotation is
  /// already says so), then the library workouts the user does not have
  /// ([addableIds], as the core says), by group, each added to the
  /// rotation with +, each saying what it would add.
  Widget _addSection(
    Set<String> addableIds,
    String currentPlanId,
    Map<String, List<MuscleGroup>> adds,
  ) {
    final l = copy.library;
    return FutureBuilder<ListTemplateLibraryResponse>(
      future: _library,
      builder: (context, snap) {
        final library = snap.data;
        if (snap.hasError) return _Note(l.loadingFailed);
        if (library == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final entries = library.templates;
        if (entries.isEmpty) return _Note(l.empty);
        final names = {for (final e in entries) e.id: e.name};
        final addable = entries
            .where((e) => addableIds.contains(e.id))
            .toList();
        if (addable.isEmpty && library.plans.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(l.addHeading),
            if (library.plans.isNotEmpty) _GroupHeading(l.plansHeading),
            for (final plan in library.plans)
              _PlanRow(
                key: ValueKey('plan-${plan.id}'),
                plan: plan,
                workouts: [for (final id in plan.libraryIds) names[id] ?? id],
                current: plan.id == currentPlanId,
                onApply: _busy.contains('plan:${plan.id}')
                    ? null
                    : () => _apply(plan),
              ),
            for (final group in _grouped(addable).entries) ...[
              _GroupHeading(group.key),
              for (final entry in group.value)
                TemplateRow(
                  name: entry.name,
                  blurb: entry.blurb,
                  exercises: entry.exercises,
                  showLifts: true,
                  note: additionLine(adds[entry.id] ?? const []),
                  actions: [
                    IconButton(
                      tooltip: l.addToPlan,
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy.contains(entry.id)
                          ? null
                          : () => _add(entry),
                      icon: const Icon(AppIcons.add, size: 20),
                    ),
                  ],
                ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final templates = wp.templates;
    final split =
        _dragged ??
        (
          rotation: templates.where((t) => t.inRotation).toList(),
          reserves: templates.where((t) => !t.inRotation).toList(),
        );
    final items = _sheetItems(split.rotation, split.reserves);
    final t = copy.library;
    final adds = additionsOf(wp.rotationCheck);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(color: AppTheme.sheetColor(context)),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AppTheme.sheetHandle(context, inset: 20)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.sheetTitle,
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
            Expanded(
              child: ReorderableListView.builder(
                scrollController: controller,
                buildDefaultDragHandles: false,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                header: switch (wp.rotationCheck) {
                  final check? => RotationCheckSection(
                    check: check,
                    names: {for (final t in templates) t.id: t.name},
                  ),
                  null => null,
                },
                footer: _addSection(
                  {...?wp.home?.addableLibraryIds},
                  wp.home?.currentPlanId ?? '',
                  adds.library,
                ),
                itemCount: items.length,
                // newIndex is already adjusted for the removed item.
                onReorderItem: (from, to) => _reorder(items, from, to),
                itemBuilder: (context, index) =>
                    _item(items[index], index, adds.templates),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One lap of the rotation: the line that says what it is, each
/// muscle's share of the most-trained one's sets on Home's bars (no
/// target, no numbers: a lap is not a week), and a plain line for each thing wrong with it (none
/// when nothing is).
class RotationCheckSection extends StatelessWidget {
  final RotationCheck check;

  /// Template id → name, for the overlap warning.
  final Map<String, String> names;

  const RotationCheckSection({
    super.key,
    required this.check,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final warnings = rotationWarningLines(check, names);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          copy.rotation.checkBody,
          style: TextStyle(fontSize: t.size.body, color: t.muted),
        ),
        const SizedBox(height: 8),
        VolumeCard(
          volume: check.volume,
          recovery: const [],
          proportional: true,
        ),
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              warning,
              style: TextStyle(
                fontSize: t.size.body,
                fontWeight: t.weight.bold,
                color: t.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Entries by group label, in library order.
Map<String, List<LibraryTemplate>> _grouped(List<LibraryTemplate> entries) {
  final out = <String, List<LibraryTemplate>>{};
  for (final e in entries) {
    out.putIfAbsent(e.groupLabel, () => []).add(e);
  }
  return out;
}

/// A section of the sheet: the rotation, the reserves, Add.
class _Heading extends StatelessWidget {
  final String label;

  /// What the section is for, under its label.
  final String? description;
  const _Heading(this.label, {this.description, super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          if (description case final text?) ...[
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(fontSize: t.size.small, color: t.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A library group under Add: programs, splits, body parts.
class _GroupHeading extends StatelessWidget {
  final String label;
  const _GroupHeading(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: t.size.small,
          fontWeight: t.weight.heavy,
          color: t.muted,
        ),
      ),
    );
  }
}

/// A ready-made plan under Add: its name, its blurb and workouts, and
/// the button that makes it the rotation, or "Current" when it is.
class _PlanRow extends StatelessWidget {
  final LibraryPlan plan;
  final List<String> workouts;
  final bool current;
  final VoidCallback? onApply;

  const _PlanRow({
    super.key,
    required this.plan,
    required this.workouts,
    required this.current,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cs = Theme.of(context).colorScheme;
    final l = copy.library;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(2, 6, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: t.size.bodyLg,
                    fontWeight: t.weight.heavy,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  workouts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: t.size.small, color: t.muted),
                ),
                if (plan.blurb.isNotEmpty)
                  Text(
                    plan.blurb,
                    style: TextStyle(
                      fontSize: t.size.small,
                      fontStyle: FontStyle.italic,
                      color: t.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (current)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l.planCurrent,
                style: TextStyle(
                  fontSize: t.size.small,
                  fontWeight: t.weight.heavy,
                  color: t.primary,
                ),
              ),
            )
          else
            IconButton(
              tooltip: l.applyPlan,
              visualDensity: VisualDensity.compact,
              onPressed: onApply,
              icon: const Icon(AppIcons.add, size: 20),
            ),
        ],
      ),
    );
  }
}

/// A section with nothing in it: the line to drop a workout on.
class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Text(
        text,
        style: TextStyle(fontSize: t.size.body, color: t.muted),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: context.tokens.size.body,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
