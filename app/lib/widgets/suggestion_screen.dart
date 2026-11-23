/// A suggestion laid out to decide on, as one change to the program, on a
/// page of its own: who and why, the week before and after, how each lift's
/// progression moves, and the other numbers it changes; then use it or not, pinned at the bottom. Home's
/// pending row and the Program screen open it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../gen/workout/v1/workout.pb.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/toast.dart';
import '../theme/theme_spec.dart';
import 'common/flat.dart';

/// Opens [suggestion] as a page of its own over the current one.
Future<void> openSuggestion(BuildContext context, Suggestion suggestion) {
  final provider = context.read<WorkoutProvider>();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/suggestion'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: SuggestionScreen(suggestion: suggestion),
      ),
    ),
  );
}

/// A progression in a sentence: "5 reps a set; hit them all and it adds
/// 5 lb", then its deload and its scheme when it has them.
String ruleText(RuleSummary r, WeightUnit unit) {
  final c = copy.suggestions;
  final step = r.incrementLb > 0
      ? formatWeight(r.incrementLb, unit, includeUnit: true)
      : c.ruleStepDefault;
  final main = switch (r.kind) {
    'fixed' =>
      c.ruleFixed
          .replaceAll('{sets}', '${r.sets}')
          .replaceAll('{reps}', '${r.reps}')
          .replaceAll(
            '{weight}',
            formatWeight(r.weightLb, unit, includeUnit: true),
          ),
    'linear' =>
      c.ruleLinear.replaceAll('{reps}', '${r.reps}').replaceAll('{step}', step),
    'double' =>
      c.ruleDouble
          .replaceAll('{low}', '${r.repLow}')
          .replaceAll('{high}', '${r.repHigh}')
          .replaceAll('{step}', step),
    'cycle' => c.ruleCycle.replaceAll('{n}', '${r.cycleSteps}'),
    'formula' => r.note.isNotEmpty ? r.note : c.ruleFormula,
    _ => c.ruleEstimatedMax,
  };
  return [
    main,
    if (r.kind == 'linear' && r.deloadAfterFails > 0)
      c.ruleDeload
          .replaceAll('{n}', '${r.deloadAfterFails}')
          .replaceAll('{pct}', '${(r.deloadFactor * 100).round()}'),
    if (r.scheme.isNotEmpty && r.scheme != 'straight')
      c.ruleScheme.replaceAll('{scheme}', _words(r.scheme)),
  ].join('. ');
}

/// A key or path as words: "classes.heavy.rest_seconds" → "Heavy rest
/// seconds".
String _words(String key) {
  final parts = key
      .replaceAll(RegExp(r'\[\d+\]'), '')
      .split('.')
      .where((p) => p != 'classes' && p.isNotEmpty)
      .map((p) => p.replaceAll('_', ' '));
  final text = parts.join(' ');
  return text.isEmpty ? key : text[0].toUpperCase() + text.substring(1);
}

String _number(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

class SuggestionScreen extends StatefulWidget {
  final Suggestion suggestion;

  const SuggestionScreen({super.key, required this.suggestion});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  ExplainSuggestionResponse? _shown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context
        .read<WorkoutProvider>()
        .explainSuggestion(widget.suggestion.id)
        .then((shown) {
          if (mounted) setState(() => _shown = shown);
        });
  }

  Future<void> _answer(bool accept) async {
    setState(() => _busy = true);
    final problem = await context.read<WorkoutProvider>().answerSuggestion(
      widget.suggestion.id,
      accept,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (problem != null) {
      final cs = Theme.of(context).colorScheme;
      showToast(
        msg: problem,
        backgroundColor: cs.inverseSurface,
        textColor: cs.onInverseSurface,
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = copy.suggestions;
    final s = widget.suggestion;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final waiting = s.status == SuggestionStatus.SUGGESTION_STATUS_UNSPECIFIED;
    final fits = s.problem.isEmpty;
    final shown = _shown;
    final muted = TextStyle(fontSize: t.size.body, color: t.muted);
    final mono = t.mono(TextStyle(fontSize: t.size.body));

    final week = <Widget>[];
    if (shown != null) {
      final before = shown.rotationBefore.join(' · ');
      final after = shown.rotationAfter.join(' · ');
      if (before != after) {
        week.add(FlatRow(label: after, subtitle: before));
      }
      for (final w in shown.workouts) {
        final line = switch (w.verb) {
          ChangeVerb.CHANGE_VERB_ADD => c.workoutAdded,
          ChangeVerb.CHANGE_VERB_REMOVE => c.workoutRemoved,
          _ => c.workoutChanged,
        };
        week.add(
          FlatRow(
            label: line.replaceAll('{name}', w.name),
            subtitle: w.exercises.isEmpty ? null : w.exercises.join(', '),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: PageTitle(c.heading)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              s.title,
              style: TextStyle(
                fontSize: t.size.titleLg,
                fontWeight: t.weight.heavy,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(c.from.replaceAll('{name}', s.fromName), style: muted),
          ),
          if (s.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(s.note, style: TextStyle(fontSize: t.size.body)),
            ),
          const SizedBox(height: 8),
          if (shown == null && fits)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (week.isNotEmpty) ...[FlatHeading(c.weekHeading), ...week],
          if (shown != null && shown.lifts.isNotEmpty) ...[
            FlatHeading(c.liftsHeading),
            for (final l in shown.lifts)
              FlatRow(
                label: l.name,
                subtitle: [
                  ruleText(l.after, unit),
                  if (l.hasBefore())
                    c.ruleWas.replaceAll('{rule}', ruleText(l.before, unit))
                  else
                    c.ruleNewLift,
                ].join('\n'),
              ),
          ],
          if (shown != null && shown.numbers.isNotEmpty) ...[
            FlatHeading(c.alsoHeading),
            for (final n in shown.numbers)
              FlatRow(
                label: _words(n.path),
                trailing: Text(
                  c.numberLine
                      .replaceAll('{before}', _number(n.before))
                      .replaceAll('{after}', _number(n.after)),
                  style: mono,
                ),
              ),
          ],
          if (waiting && !fits)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                c.noLongerFits.replaceAll('{problem}', s.problem),
                style: muted,
              ),
            ),
          if (!waiting)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.status == SuggestionStatus.SUGGESTION_STATUS_ACCEPTED
                    ? c.accepted
                    : c.declined,
                style: muted,
              ),
            ),
        ],
      ),
      // The answer stays in reach however long the change is.
      bottomNavigationBar: !waiting
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fits)
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : () => _answer(true),
                          child: Text(c.accept),
                        ),
                      ),
                    TextButton(
                      onPressed: _busy ? null : () => _answer(false),
                      child: Text(c.decline),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
