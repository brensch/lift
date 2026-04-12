import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pbenum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';

class WorkoutStartBriefingScreen extends StatefulWidget {
  final String workoutName;
  final RegimeContext? regimeContext;
  final List<ExerciseGroup> selectedGroups;
  final Future<void> Function() onStartWorkout;

  const WorkoutStartBriefingScreen({
    super.key,
    required this.workoutName,
    required this.regimeContext,
    required this.selectedGroups,
    required this.onStartWorkout,
  });

  @override
  State<WorkoutStartBriefingScreen> createState() =>
      _WorkoutStartBriefingScreenState();
}

class _WorkoutStartBriefingScreenState
    extends State<WorkoutStartBriefingScreen> {
  bool _starting = false;

  Future<void> _handleStart() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await widget.onStartWorkout();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final regimeContext = widget.regimeContext;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Start')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Message from the schplanner.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.workoutName,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 0.98,
              ),
            ),
            if (regimeContext != null &&
                regimeContext.regimeDisplayName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                regimeContext.regimeDisplayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
            if (regimeContext != null &&
                regimeContext.sessionDescription.isNotEmpty) ...[
              const SizedBox(height: 18),
              _BriefingCard(
                title: 'Today\'s brief',
                child: Text(
                  regimeContext.sessionDescription,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            if (regimeContext != null &&
                regimeContext.coachingNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BriefingCard(
                title: 'Coaching notes',
                child: Column(
                  children: [
                    for (final note in regimeContext.coachingNotes)
                      _NoteRow(note: note),
                  ],
                ),
              ),
            ],
            if (regimeContext != null &&
                regimeContext.nextSessionPreview.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BriefingCard(
                title: 'What follows',
                child: Text(
                  regimeContext.nextSessionPreview,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _BriefingCard(
              title: 'Weights and why',
              child: Column(
                children: [
                  for (final group in widget.selectedGroups)
                    _GroupWeightCard(group: group, unit: unit),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _starting ? null : _handleStart,
              icon: _starting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_starting ? 'Starting...' : 'Start workout'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _BriefingCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final String note;

  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colorScheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupWeightCard extends StatelessWidget {
  final ExerciseGroup group;
  final WeightUnit unit;

  const _GroupWeightCard({required this.group, required this.unit});

  List<WorkingSetSpec> _workingSets(ExerciseTypeConfig config) {
    if (config.workingSets.isNotEmpty) return config.workingSets;
    final count = group.sets <= 0 ? 1 : group.sets;
    return List.generate(
      count,
      (i) => WorkingSetSpec()
        ..targetWeight = count <= 1
            ? config.startWeight
            : (config.startWeight +
                  (i / (count - 1)) * (config.endWeight - config.startWeight))
        ..targetReps = config.reps
        ..isAmrap = config.lastSetAmrap && i == count - 1,
    );
  }

  String _exerciseSummary(ExerciseTypeConfig config) {
    final sets = _workingSets(config);
    if (sets.isEmpty) return 'No working sets planned.';
    return sets
        .map(
          (set) =>
              '${formatWeight(set.targetWeight.toDouble(), unit, includeUnit: true)} x '
              '${set.isAmrap ? '${set.targetReps}+' : set.targetReps}',
        )
        .join('  •  ');
  }

  bool get _isRecommendedSchplan => group.id.startsWith('recommended:');

  bool get _isPlanLaterPick => group.id.startsWith('planLater:');

  bool get _isSavedUserGroup => group.id.startsWith('saved:');

  String _schplannerReason(ExerciseTypeConfig config) {
    if (_isSavedUserGroup) {
      return 'User defined workout, schplanner not involved.';
    }

    if (_isPlanLaterPick) {
      return 'Not following the recommended schplan here. User picked this though.';
    }

    if (_isRecommendedSchplan) {
      return 'Weights picked from recommended schplan.';
    }

    final hints = _workingSets(config)
        .where((set) => set.hasProgressionHint())
        .map((set) => set.progressionHint)
        .toList(growable: false);
    if (hints.isNotEmpty) {
      final hint = hints.first;
      final parts = <String>[];
      if (hint.tier.isNotEmpty) {
        parts.add('${hint.tier.toUpperCase()} slot');
      }
      if (hint.hasRule()) {
        parts.add(_schplannerRuleLabel(hint.rule));
      }
      if (hint.amrapSuccessThreshold > 0) {
        parts.add('AMRAP target ${hint.amrapSuccessThreshold}+');
      }
      if (parts.isNotEmpty) {
        return 'Weight picked from ${parts.join(' • ')}.';
      }
    }

    if (config.workingSets.isNotEmpty) {
      return 'Weight comes from the regime\'s explicit working-set prescription.';
    }

    if (config.startWeight != config.endWeight) {
      return 'Weight ramps across the set block from ${formatWeight(config.startWeight.toDouble(), unit, includeUnit: true)} to ${formatWeight(config.endWeight.toDouble(), unit, includeUnit: true)}.';
    }

    return 'Weight is held steady at ${formatWeight(config.startWeight.toDouble(), unit, includeUnit: true)} for the planned working sets.';
  }

  String _instructionReason(ExerciseTypeConfig config) {
    final notes = _workingSets(config)
        .map((set) => set.instruction.trim())
        .where((note) => note.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (notes.isEmpty) return '';
    return notes.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (group.instruction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              group.instruction,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colorScheme.onSurface.withValues(alpha: 0.76),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final config in group.exerciseConfigs) ...[
            Text(
              exerciseNames[config.exercise] ?? 'Exercise',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _exerciseSummary(config),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _schplannerReason(config),
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
            if (_instructionReason(config).isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _instructionReason(config),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

String _schplannerRuleLabel(ProgressionRule rule) {
  switch (rule) {
    case ProgressionRule.PROGRESSION_RULE_UNSPECIFIED:
      return 'regime progression';
    case ProgressionRule.PROGRESSION_RULE_NONE:
      return 'fixed prescription';
    case ProgressionRule.PROGRESSION_RULE_ALL_SETS_MATCH_TARGET:
      return 'all sets must hit target';
    case ProgressionRule.PROGRESSION_RULE_TOP_SET_AMRAP:
      return 'top-set AMRAP check';
  }
  return 'regime progression';
}
