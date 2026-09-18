/// Onboarding's last step: tick the library templates to start with. The
/// library's defaults come ticked; at least one is required, since the
/// server treats an empty choice as "give me the defaults".
library;

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/workout.pb.dart';
import '../../home/template_library_sheet.dart';

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
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            t.body,
            style: TextStyle(
              fontSize: 14,
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
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                          child: Text(
                            group.key.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              color: cs.tertiary,
                            ),
                          ),
                        ),
                        for (final entry in group.value)
                          LibraryEntryTile(
                            entry: entry,
                            selected: selected.contains(entry.id),
                            onAdd: () => onToggle(entry.id),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
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
                            style: const TextStyle(fontWeight: FontWeight.w900),
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
