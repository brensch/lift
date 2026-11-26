/// Onboarding's last step: tick the library templates to start with. The
/// library's defaults come ticked; at least one is required, since the
/// core treats an empty choice as "give me the defaults".
library;

import 'package:material_ui/material_ui.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/workout.pb.dart';
import '../../../widgets/template_row.dart';
import '../../../theme/theme_spec.dart';
import '../../../widgets/common/flat.dart';
import '../widgets/onboarding_page.dart';

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

    return OnboardingPage(
      title: t.title,
      body: t.body,
      onBack: onBack,
      backEnabled: !isSaving,
      above: entries != null && selected.isEmpty
          ? Text(
              t.noneSelected,
              style: TextStyle(
                fontSize: context.tokens.size.small,
                fontWeight: context.tokens.weight.bold,
                color: cs.error,
              ),
            )
          : null,
      primary: OnboardingNext(
        label: t.finish,
        onPressed: canFinish ? onFinish : null,
        busy: isSaving,
      ),
      children: [
        if (error != null)
          FlatSection(
            child: Text(
              copy.library.loadingFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.muted),
            ),
          )
        else if (entries == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final group in grouped.entries) ...[
            FlatHeading(group.key),
            for (final entry in group.value)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FlatSection.margin - 2,
                ),
                child: TemplateRow(
                  name: entry.name,
                  blurb: entry.blurb,
                  exercises: entry.exercises,
                  selected: selected.contains(entry.id),
                  onTap: () => onToggle(entry.id),
                ),
              ),
          ],
      ],
    );
  }
}
