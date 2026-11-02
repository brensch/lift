/// The Edit sheet: the rotation check at the top (what one lap of the
/// rotation trains, and what is wrong with it), then the user's workouts,
/// in the same compact rows as onboarding's pick. Their own (cloned or made with New on home) come
/// first, to edit or delete; then the library (templates/library.yaml on
/// the server), ticked in and out — ticked ones follow the library, and
/// Clone makes one their own to edit.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/rotation_text.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_spec.dart';
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

  /// Open a library workout in the editor to make it the user's own:
  /// nothing changes until Save there.
  void _clone(WorkoutTemplate have) {
    final wp = context.read<WorkoutProvider>();
    Navigator.pop(context);
    showTemplateEditor(
      context,
      template: have,
      provider: wp,
      personalise: true,
    );
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
                      if (wp.rotationCheck case final check?)
                        RotationCheckSection(
                          check: check,
                          names: {for (final t in wp.templates) t.id: t.name},
                        ),
                      if (own.isNotEmpty) ...[
                        _GroupHeading(t.yoursHeading),
                        for (final template in own)
                          TemplateRow(
                            name: template.name,
                            exercises: template.exercises,
                            personal: true,
                            onTap: _busy.contains(template.id)
                                ? null
                                : () => _edit(template),
                            actions: [
                              IconButton(
                                tooltip: t.delete,
                                visualDensity: VisualDensity.compact,
                                onPressed: _busy.contains(template.id)
                                    ? null
                                    : () => _delete(template),
                                icon: Icon(
                                  AppIcons.delete,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
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
                              TemplateRow(
                                name: entry.name,
                                blurb: entry.blurb,
                                exercises: entry.exercises,
                                selected: coupled.containsKey(entry.id),
                                onTap: _busy.contains(entry.id)
                                    ? null
                                    : () => _toggle(entry, coupled[entry.id]),
                                actions: [
                                  if (coupled[entry.id] != null)
                                    _TextAction(
                                      label: t.clone,
                                      onTap: () => _clone(coupled[entry.id]!),
                                    ),
                                ],
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

/// One lap of the rotation: sets per muscle on Home's bars, and a plain
/// line for each thing wrong with it (none when nothing is).
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
    final cs = Theme.of(context).colorScheme;
    final r = copy.rotation;
    final warnings = rotationWarningLines(check, names);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeading(r.checkTitle),
        Text(
          r.checkBody,
          style: TextStyle(
            fontSize: context.tokens.size.small,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        VolumeCard(volume: check.volume, recovery: const []),
        for (final line in warnings)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              line,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                fontWeight: context.tokens.weight.bold,
                color: cs.error,
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
