/// The Manage sheet ("Your workouts"): the rotation check at the top (a
/// line, the bars of one lap of the main plan's sets per muscle, and what
/// is wrong with it); then one draggable list of the main plan (the
/// rotation) and the backups (the favourites), each row a drag handle, the
/// name and lifts, and delete; a drag reorders within a section or moves a
/// workout across into the other. Below it the library workouts the user
/// does not have yet, each added to the main plan with +. A backup or a
/// library row says which muscles it would add that the main plan trains
/// none of. Tapping one of the user's opens it in the editor.
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

Future<void> showTemplateLibrary(
  BuildContext context, {
  required WorkoutProvider provider,
}) {
  return showModalBottomSheet(
    context: context,
    routeSettings: const RouteSettings(name: 'sheet/template-library'),
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: const _LibrarySheet(),
    ),
  );
}

/// Whether the user has [entry]: a template follows it, or is their own
/// made from it. Such an entry is never offered to add again.
bool hasLibraryEntry(List<WorkoutTemplate> templates, LibraryTemplate entry) =>
    templates.any(
      (t) => t.libraryId == entry.id || t.originLibraryId == entry.id,
    );

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
  final bool main;
  const _SectionItem(this.main);
  @override
  Key get key => ValueKey('section-$main');
}

class _EmptyItem extends _Item {
  final bool main;
  const _EmptyItem(this.main);
  @override
  Key get key => ValueKey('empty-$main');
}

class _MineItem extends _Item {
  final WorkoutTemplate template;
  const _MineItem(this.template);
  @override
  Key get key => ValueKey(template.id);
}

/// The draggable list: the main plan's heading, its workouts (or the drop
/// line), then the backups' heading and theirs.
List<_Item> _sheetItems(
  List<WorkoutTemplate> main,
  List<WorkoutTemplate> backup,
) => [
  const _SectionItem(true),
  if (main.isEmpty) const _EmptyItem(true),
  for (final t in main) _MineItem(t),
  const _SectionItem(false),
  if (backup.isEmpty) const _EmptyItem(false),
  for (final t in backup) _MineItem(t),
];

/// The list after a drag: every workout above the backups' heading is in
/// the main plan (one dropped above the main plan's heading too), the rest
/// are backups, each in the order shown.
({List<WorkoutTemplate> main, List<WorkoutTemplate> backup}) _splitItems(
  List<_Item> items,
) {
  final main = <WorkoutTemplate>[];
  final backup = <WorkoutTemplate>[];
  var inBackup = false;
  for (final item in items) {
    switch (item) {
      case _SectionItem(main: false):
        inBackup = true;
      case _MineItem(:final template):
        (inBackup ? backup : main).add(template);
      default:
        break;
    }
  }
  return (main: main, backup: backup);
}

class _LibrarySheetState extends State<_LibrarySheet> {
  late Future<List<LibraryTemplate>> _library;
  final Set<String> _busy = {};

  /// A drag's result, shown until the core's answer replaces it.
  ({List<WorkoutTemplate> main, List<WorkoutTemplate> backup})? _dragged;

  @override
  void initState() {
    super.initState();
    _library = context.read<WorkoutProvider>().service.listTemplateLibrary();
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

  /// A drag in the list: one reorder that also says where the main plan
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
        for (final t in [...split.main, ...split.backup]) t.id,
      ], rotationCount: split.main.length),
    );
    if (mounted) setState(() => _dragged = null);
  }

  /// A library workout, into the main plan.
  Future<void> _add(LibraryTemplate entry) {
    final wp = context.read<WorkoutProvider>();
    return _run(
      entry.id,
      () => wp.addLibraryTemplates([entry.id], inRotation: true),
    );
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
              child: const Text('Cancel'),
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
  /// backup says what it would add.
  Widget _item(_Item item, int index, Map<String, List<MuscleGroup>> adds) {
    final l = copy.library;
    final cs = Theme.of(context).colorScheme;
    return switch (item) {
      _SectionItem(:final main) => _Heading(
        key: item.key,
        main ? l.rotationHeading : l.favouritesHeading,
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

  /// Below the list: the library workouts the user does not have, by
  /// group, each added to the main plan with +, each saying what it would
  /// add.
  Widget _addSection(
    List<WorkoutTemplate> templates,
    Map<String, List<MuscleGroup>> adds,
  ) {
    final l = copy.library;
    return FutureBuilder<List<LibraryTemplate>>(
      future: _library,
      builder: (context, snap) {
        final entries = snap.data;
        if (snap.hasError) return _Note(l.loadingFailed);
        if (entries == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (entries.isEmpty) return _Note(l.empty);
        final addable = entries
            .where((e) => !hasLibraryEntry(templates, e))
            .toList();
        if (addable.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(l.addHeading),
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
          main: templates.where((t) => t.inRotation).toList(),
          backup: templates.where((t) => !t.inRotation).toList(),
        );
    final items = _sheetItems(split.main, split.backup);
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
                footer: _addSection(templates, adds.library),
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

/// One lap of the main plan: the line that says what it is, its sets per
/// muscle on Home's bars, and a plain line for each thing wrong with it
/// (none when nothing is).
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
        VolumeCard(volume: check.volume, recovery: const []),
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

/// A section of the sheet: the main plan, the backups, Add.
class _Heading extends StatelessWidget {
  final String label;
  const _Heading(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 4),
    child: SectionLabel(label),
  );
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
