/// Onboarding's last step: tick the library templates to start with. The
/// library's defaults come ticked; at least one is required, since the
/// server treats an empty choice as "give me the defaults".
library;

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/workout.pb.dart';
import '../../../logic/exercises.dart';
import '../../home/template_library_sheet.dart';
import '../../../theme/theme_spec.dart';
import '../../../theme/app_icons.dart';

class TemplatesStep extends StatelessWidget {
  final List<LibraryTemplate>? library; // null while loading
  final Object? error;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const TemplatesStep({
    super.key,
    required this.library,
    required this.error,
    required this.selected,
    required this.onToggle,
    required this.isSaving,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.onboarding.templates;
    final entries = library;
    final grouped = <String, List<LibraryTemplate>>{};
    for (final e in entries ?? const <LibraryTemplate>[]) {
      grouped.putIfAbsent(e.groupLabel, () => []).add(e);
    }
    final canFinish = selected.isNotEmpty && !isSaving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            style: TextStyle(
              fontSize: context.tokens.size.headline,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.body,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: error != null
                ? Center(
                    child: Text(
                      copy.library.loadingFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : entries == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final group in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
                          child: Text(
                            group.key.toUpperCase(),
                            style: TextStyle(
                              fontSize: context.tokens.size.small,
                              fontWeight: context.tokens.weight.heavy,
                              letterSpacing: 1.4,
                              color: cs.tertiary,
                            ),
                          ),
                        ),
                        for (final entry in group.value)
                          _TemplateRow(
                            entry: entry,
                            selected: selected.contains(entry.id),
                            onToggle: () => onToggle(entry.id),
                          ),
                      ],
                    ],
                  ),
          ),
          if (entries != null && selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t.noneSelected,
                style: TextStyle(
                  fontSize: context.tokens.size.small,
                  fontWeight: context.tokens.weight.bold,
                  color: cs.error,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onBack,
                    child: Text(copy.onboarding.back),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: canFinish ? onFinish : null,
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            t.finish,
                            style: TextStyle(
                              fontWeight: context.tokens.weight.heavy,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One table row: tick box, name, and a chevron that drops down the
/// exercise list so the whole library fits on screen until you want detail.
class _TemplateRow extends StatefulWidget {
  final LibraryTemplate entry;
  final bool selected;
  final VoidCallback onToggle;

  const _TemplateRow({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  @override
  State<_TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends State<_TemplateRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final selected = widget.selected;
    final names = entry.exercises
        .map((e) => exerciseNames[e] ?? e.name)
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: widget.onToggle,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
            child: Row(
              children: [
                SelectBox(selected: selected, colorScheme: cs),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: context.tokens.size.bodyLg,
                      fontWeight: selected
                          ? context.tokens.weight.heavy
                          : context.tokens.weight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _open = !_open),
                  icon: Icon(_open ? AppIcons.expandUp : AppIcons.expandDown),
                  color: cs.onSurface.withValues(alpha: 0.6),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 6, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.blurb.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      entry.blurb,
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                Text(
                  names,
                  style: TextStyle(
                    fontSize: context.tokens.size.small,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
