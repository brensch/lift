/// A change someone suggested, laid out to decide on: who and why, what it
/// changes in plain words, a workout's plan as it would start today, then
/// add it or not. Home's Suggested row and the Program screen open it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/plan_text.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/toast.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
import 'common/flat.dart';

Future<void> showSuggestionSheet(BuildContext context, Suggestion suggestion) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.sheetColor(context),
    builder: (_) => SuggestionSheet(suggestion: suggestion),
  );
}

/// One change in words: "Adds the workout Push", "Sets volume".
String changeText(SuggestedChange c) {
  final t = copy.suggestions;
  final verb = switch (c.verb) {
    ChangeVerb.CHANGE_VERB_ADD => t.verbAdd,
    ChangeVerb.CHANGE_VERB_CHANGE => t.verbChange,
    ChangeVerb.CHANGE_VERB_REMOVE => t.verbRemove,
    _ => t.verbSet,
  };
  final subject = switch (c.subject) {
    ChangeSubject.CHANGE_SUBJECT_WORKOUT => t.subjectWorkout,
    ChangeSubject.CHANGE_SUBJECT_EXERCISE => t.subjectExercise,
    ChangeSubject.CHANGE_SUBJECT_SCHEME => t.subjectScheme,
    ChangeSubject.CHANGE_SUBJECT_PROGRESSION => t.subjectProgression,
    ChangeSubject.CHANGE_SUBJECT_CLASS => t.subjectClass,
    _ => '',
  };
  return [verb, subject, c.name].where((w) => w.isNotEmpty).join(' ');
}

class SuggestionSheet extends StatefulWidget {
  final Suggestion suggestion;

  const SuggestionSheet({super.key, required this.suggestion});

  @override
  State<SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends State<SuggestionSheet> {
  TemplatePlan? _plan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final exercises = widget.suggestion.exercises;
    if (exercises.isNotEmpty) {
      context.read<WorkoutProvider>().planTemplate(exercises).then((plan) {
        if (mounted) setState(() => _plan = plan);
      });
    }
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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AppTheme.sheetHandle(context)),
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
              child: Text(
                c.from.replaceAll('{name}', s.fromName),
                style: TextStyle(fontSize: t.size.body, color: t.muted),
              ),
            ),
            if (s.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(s.note, style: TextStyle(fontSize: t.size.body)),
              ),
            const SizedBox(height: 12),
            FlatHeading(c.changesHeading),
            for (final change in s.changes)
              FlatRow(label: changeText(change)),
            // A workout: its lifts as they'd start today.
            for (final p in _plan?.plans ?? const <ExercisePlan>[])
              if (p.hasDecision())
                FlatRow(
                  label: exerciseName(p.decision.exercise),
                  trailing: Text(
                    planLine(p.decision, unit),
                    style: t.mono(TextStyle(fontSize: t.size.body)),
                  ),
                ),
            if (waiting && !fits)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  c.noLongerFits.replaceAll('{problem}', s.problem),
                  style: TextStyle(fontSize: t.size.body, color: t.muted),
                ),
              ),
            if (waiting)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fits)
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : () => _answer(true),
                          child: Text(
                            s.kind == 'workout'
                                ? c.acceptWorkout
                                : c.acceptProgram,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: _busy ? null : () => _answer(false),
                      child: Text(c.decline),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  s.status == SuggestionStatus.SUGGESTION_STATUS_ACCEPTED
                      ? c.accepted
                      : c.declined,
                  style: TextStyle(fontSize: t.size.body, color: t.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
