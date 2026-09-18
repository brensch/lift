/// The Add sheet: make a template from scratch, or copy one from the
/// library (templates/library.yaml on the backend). Copies land in the
/// user's list tagged with their library id, so the sheet can show what is
/// already there.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import 'template_editor.dart';

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
  final Set<String> _adding = {};

  @override
  void initState() {
    super.initState();
    _library = context.read<WorkoutProvider>().service.listTemplateLibrary();
  }

  Future<void> _add(LibraryTemplate entry) async {
    if (_adding.contains(entry.id)) return;
    setState(() => _adding.add(entry.id));
    try {
      await context.read<WorkoutProvider>().addLibraryTemplates([entry.id]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(entry.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wp = context.watch<WorkoutProvider>();
    final have = {
      for (final t in wp.templates)
        if (t.libraryId.isNotEmpty) t.libraryId,
    };
    final t = copy.library;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: AppTheme.sheetColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLg),
          ),
          border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AppTheme.sheetHandle(context)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.sheetTitle,
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
                      _MakeYourOwnTile(
                        onTap: () {
                          final wp = context.read<WorkoutProvider>();
                          Navigator.pop(context);
                          showTemplateEditor(
                            context,
                            template: null,
                            provider: wp,
                          );
                        },
                      ),
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
                                added: have.contains(entry.id),
                                busy: _adding.contains(entry.id),
                                onAdd: () => _add(entry),
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
          fontSize: 11,
          fontWeight: FontWeight.w900,
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
          fontSize: 14,
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
      borderRadius: AppTheme.brMd,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          borderRadius: AppTheme.brMd,
          border: Border.all(color: cs.primary, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.makeYourOwn,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    t.makeYourOwnHint,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
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

  const LibraryEntryTile({
    super.key,
    required this.entry,
    required this.onAdd,
    this.added = false,
    this.busy = false,
    this.selected,
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
      onTap: tick != null ? onAdd : null,
      borderRadius: AppTheme.brMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: outlined ? cs.primary.withValues(alpha: 0.08) : null,
          borderRadius: AppTheme.brMd,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (entry.blurb.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry.blurb,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      names,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (tick != null)
              Icon(
                tick ? Icons.check_circle : Icons.circle_outlined,
                color: tick ? cs.primary : cs.outline,
              )
            else if (added)
              Text(
                t.added,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppTheme.successFg,
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
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
