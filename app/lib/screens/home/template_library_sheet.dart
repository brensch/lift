/// The Edit sheet: the user's workouts. Library workouts
/// (templates/library.yaml on the server) are ticked in and out and follow
/// the library; Clone makes one the user's own to edit. Their own workouts
/// (cloned or made from scratch) are edited or deleted.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_spec.dart';
import 'template_editor.dart';
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

class _LibrarySheet extends StatefulWidget {
  const _LibrarySheet();

  @override
  State<_LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends State<_LibrarySheet> {
  late Future<List<LibraryTemplate>> _library;
  final Set<String> _busy = {};

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

  /// Tick a library workout in (it follows the library) or out.
  Future<void> _toggle(LibraryTemplate entry, WorkoutTemplate? have) {
    final wp = context.read<WorkoutProvider>();
    return _run(
      entry.id,
      () => have == null
          ? wp.addLibraryTemplates([entry.id])
          : wp.deleteTemplate(have.id),
    );
  }

  /// Make a library workout the user's own and open it to edit.
  Future<void> _clone(WorkoutTemplate have) async {
    final wp = context.read<WorkoutProvider>();
    final navigator = Navigator.of(context);
    final parent = navigator.context;
    final cloned = await wp.cloneTemplate(have.id);
    navigator.pop();
    if (parent.mounted) {
      await showTemplateEditor(parent, template: cloned, provider: wp);
    }
  }

  void _edit(WorkoutTemplate? template) {
    final wp = context.read<WorkoutProvider>();
    Navigator.pop(context);
    showTemplateEditor(context, template: template, provider: wp);
  }

  Future<void> _delete(WorkoutTemplate template) async {
    final wp = context.read<WorkoutProvider>();
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
    if (sure == true) {
      await _run(template.id, () => wp.deleteTemplate(template.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final coupled = {
      for (final t in wp.templates)
        if (t.coupled) t.libraryId: t,
    };
    final own = wp.templates.where((t) => !t.coupled).toList();
    final t = copy.library;

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
            const SizedBox(height: 4),
            Expanded(
              child: FutureBuilder<List<LibraryTemplate>>(
                future: _library,
                builder: (context, snap) {
                  final entries = snap.data;
                  return ListView(
                    controller: controller,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    children: [
                      _MakeYourOwnTile(onTap: () => _edit(null)),
                      if (own.isNotEmpty) ...[
                        _GroupHeading(t.yoursHeading),
                        for (final template in own)
                          _OwnTile(
                            template: template,
                            busy: _busy.contains(template.id),
                            onEdit: () => _edit(template),
                            onDelete: () => _delete(template),
                          ),
                      ],
                      if (snap.hasError)
                        _Note(t.loadingFailed)
                      else if (entries == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (entries.isEmpty)
                        _Note(t.empty)
                      else
                        ..._grouped(entries).entries.expand(
                          (group) => [
                            _GroupHeading(group.key),
                            for (final entry in group.value)
                              LibraryEntryTile(
                                entry: entry,
                                selected: coupled.containsKey(entry.id),
                                busy: _busy.contains(entry.id),
                                onAdd: () => _toggle(entry, coupled[entry.id]),
                                action: coupled[entry.id] == null
                                    ? null
                                    : _TextAction(
                                        label: t.clone,
                                        onTap: () => _clone(coupled[entry.id]!),
                                      ),
                              ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

class _GroupHeading extends StatelessWidget {
  final String label;
  const _GroupHeading(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: context.tokens.size.small,
          fontWeight: context.tokens.weight.heavy,
          letterSpacing: 1.4,
          color: cs.tertiary,
        ),
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

class _MakeYourOwnTile extends StatelessWidget {
  final VoidCallback onTap;
  const _MakeYourOwnTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.library;
    return InkWell(
      onTap: onTap,
      borderRadius: context.tokens.brMd,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          borderRadius: context.tokens.brMd,
          border: Border.all(color: cs.primary, width: 2),
        ),
        child: Row(
          children: [
            Icon(AppIcons.edit, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.makeYourOwn,
                    style: TextStyle(
                      fontSize: context.tokens.size.bodyLg,
                      fontWeight: context.tokens.weight.heavy,
                    ),
                  ),
                  Text(
                    t.makeYourOwnHint,
                    style: TextStyle(
                      fontSize: context.tokens.size.small,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.forward, color: cs.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

/// One of the user's own workouts: its name marked as theirs, its
/// exercises, and edit / delete.
class _OwnTile extends StatelessWidget {
  final WorkoutTemplate template;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OwnTile({
    required this.template,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = template.exercises
        .map((e) => exerciseNames[e] ?? e.name)
        .join(' · ');
    return InkWell(
      onTap: busy ? null : onEdit,
      borderRadius: context.tokens.brMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          borderRadius: context.tokens.brMd,
          border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                      fontSize: context.tokens.size.bodyLg,
                      fontWeight: context.tokens.weight.heavy,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const PersonalTag(),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      names,
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: busy ? null : onEdit,
              icon: Icon(AppIcons.edit, size: 20, color: cs.onSurface),
            ),
            IconButton(
              onPressed: busy ? null : onDelete,
              icon: Icon(AppIcons.delete, size: 20, color: cs.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks a workout as the user's own: on home and in the Edit sheet.
class PersonalTag extends StatelessWidget {
  const PersonalTag({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.copy, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            copy.library.personal.toUpperCase(),
            style: TextStyle(
              fontSize: context.tokens.size.small,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: 0.8,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: cs.outline),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: context.tokens.size.small,
            fontWeight: context.tokens.weight.heavy,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

/// One library entry: name, blurb, its exercises, and ADD / ADDED. Also
/// used by onboarding in tick mode (`selected` given instead of `added`).
class LibraryEntryTile extends StatelessWidget {
  final LibraryTemplate entry;
  final bool added;
  final bool busy;
  final VoidCallback onAdd;
  final bool? selected;

  /// Beside the tick box (tick mode): the sheet's Clone.
  final Widget? action;

  const LibraryEntryTile({
    super.key,
    required this.entry,
    required this.onAdd,
    this.added = false,
    this.busy = false,
    this.selected,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.library;
    final tick = selected;
    final outlined = tick ?? false;
    final names = entry.exercises
        .map((e) => exerciseNames[e] ?? e.name)
        .join(' · ');
    return InkWell(
      onTap: tick != null && !busy ? onAdd : null,
      borderRadius: context.tokens.brMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: outlined ? cs.primary.withValues(alpha: 0.08) : null,
          borderRadius: context.tokens.brMd,
          border: Border.all(
            color: outlined ? cs.primary : cs.outline.withValues(alpha: 0.5),
            width: outlined ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: context.tokens.size.bodyLg,
                      fontWeight: context.tokens.weight.heavy,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (entry.blurb.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry.blurb,
                        style: TextStyle(
                          fontSize: context.tokens.size.small,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      names,
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (action != null)
              Padding(padding: const EdgeInsets.only(right: 10), child: action),
            if (tick != null)
              SelectBox(selected: tick, colorScheme: cs)
            else if (added)
              Text(
                t.added,
                style: TextStyle(
                  fontSize: context.tokens.size.small,
                  fontWeight: context.tokens.weight.heavy,
                  letterSpacing: 0.8,
                  color: context.tokens.successFg,
                ),
              )
            else
              SizedBox(
                height: 34,
                child: FilledButton(
                  onPressed: busy ? null : onAdd,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          t.add,
                          style: TextStyle(
                            fontSize: context.tokens.size.small,
                            fontWeight: context.tokens.weight.heavy,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A square tick box for multi-select lists. Deliberately not a circle, which
/// reads as a radio button (pick one) when the user can pick many.
class SelectBox extends StatelessWidget {
  final bool selected;
  final ColorScheme colorScheme;

  const SelectBox({
    super.key,
    required this.selected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? cs.primary : Colors.transparent,
        borderRadius: context.tokens.br(5),
        border: Border.all(
          color: selected ? cs.primary : cs.outline,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(AppIcons.check, size: 16, color: cs.onPrimary)
          : null,
    );
  }
}
