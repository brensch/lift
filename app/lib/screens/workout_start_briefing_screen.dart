import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pbenum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../widgets/user_message_chip.dart';
import '../widgets/phase_explanation.dart';

List<String> _slotKeysForStartConfig(ExerciseTypeConfig config) {
  final keys = <String>{};
  for (final set in config.workingSets) {
    if (set.hasProgressionHint() && set.progressionHint.slotKey.isNotEmpty) {
      keys.add(set.progressionHint.slotKey);
    }
  }
  return keys.toList(growable: false);
}

class WorkoutStartBriefingScreen extends StatefulWidget {
  final String workoutName;
  final RegimeContext? regimeContext;
  final List<UserMessage> scheduleMessages;
  final List<ExerciseGroup> selectedGroups;
  final String estimatedTimeLabel;
  final Future<void> Function() onStartWorkout;

  const WorkoutStartBriefingScreen({
    super.key,
    required this.workoutName,
    required this.regimeContext,
    required this.scheduleMessages,
    required this.selectedGroups,
    required this.estimatedTimeLabel,
    required this.onStartWorkout,
  });

  @override
  State<WorkoutStartBriefingScreen> createState() =>
      _WorkoutStartBriefingScreenState();
}

class _WorkoutStartBriefingScreenState
    extends State<WorkoutStartBriefingScreen> {
  bool _starting = false;

  // ── Message routing ───────────────────────────────────────────────────────

  List<UserMessage> _displayMessages() {
    return widget.scheduleMessages
        .where(
          (message) => message.body.trim().isNotEmpty || message.hasDetails(),
        )
        .toList(growable: false);
  }

  List<UserMessage> _globalMessages(List<UserMessage> messages) {
    return messages
        .where(
          (message) =>
              message.exercise == Exercise.EXERCISE_UNSPECIFIED &&
              message.slotKey.isEmpty,
        )
        .toList(growable: false);
  }

  List<UserMessage> _messagesForConfig(
    ExerciseTypeConfig config,
    List<UserMessage> messages,
  ) {
    final slotKeys = _slotKeysForStartConfig(config).toSet();
    final seen = <String>{};
    final out = <UserMessage>[];
    for (final message in messages) {
      if (message.exercise == Exercise.EXERCISE_UNSPECIFIED &&
          message.slotKey.isEmpty) {
        continue;
      }
      final matchesSlot =
          message.slotKey.isNotEmpty && slotKeys.contains(message.slotKey);
      final matchesExercise = message.exercise == config.exercise;
      if (!matchesSlot && !matchesExercise) continue;
      if (!seen.add(message.messageKey)) continue;
      out.add(message);
    }
    return out;
  }

  // ── Plan summary ──────────────────────────────────────────────────────────

  List<WorkingSetSpec> _workingSets(ExerciseGroup group, ExerciseTypeConfig c) {
    if (c.workingSets.isNotEmpty) return c.workingSets;
    final count = group.sets <= 0 ? 1 : group.sets;
    return List.generate(
      count,
      (i) => WorkingSetSpec()
        ..targetWeight = count <= 1
            ? c.startWeight
            : (c.startWeight + (i / (count - 1)) * (c.endWeight - c.startWeight))
        ..targetReps = c.reps
        ..isAmrap = c.lastSetAmrap && i == count - 1,
    );
  }

  int _exerciseCount() => widget.selectedGroups.fold(
    0,
    (total, g) => total + g.exerciseConfigs.length,
  );

  int _workingSetCount() {
    var total = 0;
    for (final g in widget.selectedGroups) {
      for (final c in g.exerciseConfigs) {
        total += _workingSets(g, c).length;
      }
    }
    return total;
  }

  double? _topWeight() {
    double? top;
    for (final g in widget.selectedGroups) {
      for (final c in g.exerciseConfigs) {
        for (final s in _workingSets(g, c)) {
          final w = s.targetWeight.toDouble();
          if (top == null || w > top) top = w;
        }
      }
    }
    return top;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

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
    final displayMessages = _displayMessages();
    final globalMessages = _globalMessages(displayMessages);

    final title = _workoutTitle(widget.workoutName);
    final programName = regimeContext?.regimeDisplayName.trim() ?? '';
    final sessionDescription = regimeContext?.sessionDescription.trim() ?? '';
    final topWeight = _topWeight();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _Eyebrow(programName: programName),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              height: 1.02,
            ),
          ),
          if (sessionDescription.isNotEmpty &&
              sessionDescription.toLowerCase() != title.toLowerCase()) ...[
            const SizedBox(height: 8),
            Text(
              sessionDescription,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // ── At-a-glance ───────────────────────────────────────────────────
          const SizedBox(height: 20),
          _StatBand(
            tiles: [
              _StatTile(value: '${_exerciseCount()}', label: 'exercises'),
              _StatTile(value: '${_workingSetCount()}', label: 'work sets'),
              if (widget.estimatedTimeLabel.isNotEmpty &&
                  widget.estimatedTimeLabel != '--')
                _StatTile(value: widget.estimatedTimeLabel, label: 'est. time'),
              if (topWeight != null)
                _StatTile(
                  value: formatWeight(topWeight, unit),
                  label: 'top ${weightUnitSuffix(unit)}',
                ),
            ],
          ),

          // ── Where you are in the cycle ────────────────────────────────────
          if (regimeContext != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: PhaseExplanation(
                context: regimeContext,
                showHeadline: false,
              ),
            ),
          ],

          // ── The plan ──────────────────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionLabel(text: 'The schplan'),
          const SizedBox(height: 12),
          for (final group in widget.selectedGroups)
            _PlanGroupCard(
              group: group,
              unit: unit,
              workingSetsOf: (c) => _workingSets(group, c),
              messagesOf: (c) => _messagesForConfig(c, displayMessages),
            ),

          // ── Coach voice ───────────────────────────────────────────────────
          if (globalMessages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CoachCard(messages: globalMessages),
          ],
        ],
      ),
      bottomNavigationBar: _StartBar(
        starting: _starting,
        exerciseCount: _exerciseCount(),
        setCount: _workingSetCount(),
        onStart: _handleStart,
      ),
    );
  }
}

// ─── Hero eyebrow ───────────────────────────────────────────────────────────

class _Eyebrow extends StatelessWidget {
  final String programName;
  const _Eyebrow({required this.programName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (programName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 13,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  programName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
        Text(
          'schplanner brief',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

// ─── At-a-glance stat band ──────────────────────────────────────────────────

class _StatTile {
  final String value;
  final String label;
  const _StatTile({required this.value, required this.label});
}

class _StatBand extends StatelessWidget {
  final List<_StatTile> tiles;
  const _StatBand({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 32,
                color: colorScheme.outline.withValues(alpha: 0.18),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(
                      tiles[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tiles[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─── Plan group card ────────────────────────────────────────────────────────

class _PlanGroupCard extends StatelessWidget {
  final ExerciseGroup group;
  final WeightUnit unit;
  final List<WorkingSetSpec> Function(ExerciseTypeConfig) workingSetsOf;
  final List<UserMessage> Function(ExerciseTypeConfig) messagesOf;

  const _PlanGroupCard({
    required this.group,
    required this.unit,
    required this.workingSetsOf,
    required this.messagesOf,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSuperset = group.exerciseConfigs.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperset) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _Badge(
                  text: 'SUPERSET',
                  color: colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          for (int i = 0; i < group.exerciseConfigs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outline.withValues(alpha: 0.14),
                ),
              ),
            _ExerciseBlock(
              config: group.exerciseConfigs[i],
              unit: unit,
              showName: isSuperset,
              fallbackName: isSuperset ? null : group.name,
              workingSets: workingSetsOf(group.exerciseConfigs[i]),
              messages: messagesOf(group.exerciseConfigs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Exercise block ─────────────────────────────────────────────────────────

class _ExerciseBlock extends StatelessWidget {
  final ExerciseTypeConfig config;
  final WeightUnit unit;
  final bool showName;
  final String? fallbackName;
  final List<WorkingSetSpec> workingSets;
  final List<UserMessage> messages;

  const _ExerciseBlock({
    required this.config,
    required this.unit,
    required this.showName,
    required this.fallbackName,
    required this.workingSets,
    required this.messages,
  });

  String get _name {
    final exerciseName = exerciseNames[config.exercise];
    if (showName) return exerciseName ?? 'Exercise';
    final fallback = fallbackName?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return exerciseName ?? 'Exercise';
  }

  double? _topWeight() {
    double? top;
    for (final s in workingSets) {
      final w = s.targetWeight.toDouble();
      if (top == null || w > top) top = w;
    }
    return top;
  }

  bool _hasAmrap() => workingSets.any((s) => s.isAmrap);

  String _instructionReason() {
    final notes = workingSets
        .map((s) => s.instruction.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return notes.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reason = _instructionReason();
    final topWeight = _topWeight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (_hasAmrap()) ...[
                    const SizedBox(width: 8),
                    _Badge(text: 'AMRAP', color: colorScheme.tertiary),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            _Metric(label: 'SETS', value: '${workingSets.length}'),
            if (topWeight != null) ...[
              const SizedBox(width: 18),
              _Metric(
                label: 'MAX',
                value: formatWeight(topWeight, unit, includeUnit: true),
              ),
            ],
          ],
        ),
        if (messages.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: UserMessageChip(message: message, compact: true),
            ),
        ],
        if (reason.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: messages.isNotEmpty ? 0 : 8),
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Coach card (schplanner voice) ──────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  final List<UserMessage> messages;

  const _CoachCard({required this.messages});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                size: 16,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'FROM THE SCHPLANNER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: UserMessageChip(message: message, compact: true),
            ),
        ],
      ),
    );
  }
}

// ─── Compact labelled metric (SETS / MAX) ───────────────────────────────────

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─── Small badge ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

// ─── Pinned start bar ───────────────────────────────────────────────────────

class _StartBar extends StatelessWidget {
  final bool starting;
  final int exerciseCount;
  final int setCount;
  final VoidCallback onStart;

  const _StartBar({
    required this.starting,
    required this.exerciseCount,
    required this.setCount,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final panelColor = colorScheme.brightness == Brightness.dark
        ? const Color(0xFF222222)
        : const Color(0xFFF0F0F0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colorScheme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.10),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}  ·  $setCount work sets',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              onPressed: starting ? null : onStart,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: starting
                  ? const SizedBox.shrink()
                  : const Icon(Icons.play_arrow_rounded, size: 24),
              label: starting
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Text(
                      'START WORKOUT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Workout names arrive as "YYYY/MM/DD - Base name". Strip the date prefix so
/// the big title carries the meaningful base name rather than today's date.
String _workoutTitle(String full) {
  final idx = full.indexOf(' - ');
  if (idx <= 0) return full.trim();
  final rest = full.substring(idx + 3).trim();
  return rest.isEmpty ? full.trim() : rest;
}
