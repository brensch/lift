import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/plate_visualization.dart';

String _fmt(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─── Shared components ──────────────────────────────────────────────

/// Compact next set info: exercise name, warmup badge, weight × reps, plates
class _NextSetInfo extends StatelessWidget {
  final ProposedSet set;
  final bool large;

  const _NextSetInfo({required this.set, this.large = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[set.exercise] ?? '?';
    final unit = context.watch<SettingsProvider>().weightUnit;
    final weightText = formatWeight(set.targetWeight.toDouble(), unit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: large ? 16 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (set.warmup) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.warmupFg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'W',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warmupFg,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              set.isAmrap
                  ? '$weightText \u00D7 AMRAP'
                  : '$weightText \u00D7 ${set.targetReps}',
              style: TextStyle(
                fontSize: large ? 18 : 14,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              ' ${weightUnitSuffix(unit)}',
              style: TextStyle(
                fontSize: large ? 13 : 11,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 8),
            PlateVisualization(weight: set.targetWeight.toDouble()),
          ],
        ),
      ],
    );
  }
}

/// Left-accent card shell matching browser style
class _AccentBox extends StatelessWidget {
  final Color accentColor;
  final bool dashed;
  final Widget child;

  const _AccentBox({
    required this.accentColor,
    this.dashed = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dashed ? colorScheme.outline : colorScheme.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accentColor),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ],
      ),
    );
  }
}

/// Button row: primary action + optional skip warmup
class _ActionRow extends StatelessWidget {
  final String label;
  final VoidCallback onAction;
  final VoidCallback? onSkipWarmup;

  const _ActionRow({
    required this.label,
    required this.onAction,
    this.onSkipWarmup,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onSkipWarmup != null) ...[
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: onSkipWarmup,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: onAction,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── GroupNextUpBox ─────────────────────────────────────────────────

class GroupNextUpBox extends StatelessWidget {
  final ParticipantStatus participant;
  final int restUntilTimestamp; // unix seconds
  final ProposedSet? nextSet;
  final bool isMe;
  final DateTime now;

  const GroupNextUpBox({
    super.key,
    required this.participant,
    required this.restUntilTimestamp,
    this.nextSet,
    this.isMe = false,
    required this.now,
  });

  static const _purple = Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    if (nextSet == null) return const SizedBox.shrink();

    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
    final remaining = restUntilTimestamp - nowUnix;
    final isOverdue = remaining <= 0;
    final name = participant.user.name;

    return IntrinsicHeight(
      child: _AccentBox(
        accentColor: _purple,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe
                        ? "You're next! Don't hold them up"
                        : 'Next for Group \u00B7 $name',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: _purple,
                    ),
                  ),
                  if (!isMe) ...[
                    const SizedBox(height: 4),
                    _NextSetInfo(set: nextSet!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isOverdue)
              const Text(
                'Overdue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: _purple,
                ),
              )
            else
              Text(
                _fmt(remaining),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── RestingBox ─────────────────────────────────────────────────────

class RestingBox extends StatelessWidget {
  final int secondsRemaining;
  final ProposedSet? nextSet;
  final VoidCallback onStartEarly;
  final VoidCallback? onSkipWarmup;

  const RestingBox({
    super.key,
    required this.secondsRemaining,
    this.nextSet,
    required this.onStartEarly,
    this.onSkipWarmup,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: _AccentBox(
        accentColor: AppTheme.workoutRestingFg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your next set',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppTheme.workoutRestingFg,
                        ),
                      ),
                      if (nextSet != null) ...[
                        const SizedBox(height: 4),
                        _NextSetInfo(set: nextSet!, large: true),
                      ],
                    ],
                  ),
                ),
                Text(
                  _fmt(secondsRemaining),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ActionRow(
              label: 'Start Next Set',
              onAction: onStartEarly,
              onSkipWarmup: nextSet?.warmup == true ? onSkipWarmup : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ChatTimeBox ────────────────────────────────────────────────────

class ChatTimeBox extends StatelessWidget {
  final int elapsedSeconds;
  final ProposedSet nextSet;
  final VoidCallback onStart;
  final VoidCallback? onSkipWarmup;

  const ChatTimeBox({
    super.key,
    required this.elapsedSeconds,
    required this.nextSet,
    required this.onStart,
    this.onSkipWarmup,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: _AccentBox(
        accentColor: AppTheme.workoutYappingFg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your next set',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppTheme.workoutYappingFg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _NextSetInfo(set: nextSet, large: true),
                    ],
                  ),
                ),
                Text(
                  _fmt(elapsedSeconds),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: -2,
                    color: AppTheme.workoutYappingFg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ActionRow(
              label: 'Start Set',
              onAction: onStart,
              onSkipWarmup: nextSet.warmup ? onSkipWarmup : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ActiveSetBox ───────────────────────────────────────────────────

class ActiveSetBox extends StatefulWidget {
  final ProposedSet proposedSet;
  final CompletedSet? activeCompletedSet;
  final DateTime now;
  final void Function(int reps, double weight) onComplete;
  final VoidCallback? onSkipWarmup;

  const ActiveSetBox({
    super.key,
    required this.proposedSet,
    this.activeCompletedSet,
    required this.now,
    required this.onComplete,
    this.onSkipWarmup,
  });

  @override
  State<ActiveSetBox> createState() => _ActiveSetBoxState();
}

class _ActiveSetBoxState extends State<ActiveSetBox> {
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: widget.proposedSet.targetReps,
    );
  }

  @override
  void didUpdateWidget(ActiveSetBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposedSet.targetReps != widget.proposedSet.targetReps) {
      _scrollController.jumpToItem(widget.proposedSet.targetReps);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final elapsedSecs = widget.activeCompletedSet != null
        ? (widget.now.millisecondsSinceEpoch ~/ 1000) -
              widget.activeCompletedSet!.startedAt.toInt()
        : 0;
    final name = exerciseNames[widget.proposedSet.exercise] ?? '?';
    final isWarmup = widget.proposedSet.warmup;
    final accentColor = AppTheme.workoutLiftingFg;

    return IntrinsicHeight(
      child: _AccentBox(
        accentColor: accentColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: exercise name + warmup badge + elapsed time
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isWarmup) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warmupFg.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Warmup',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warmupFg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  _fmt(elapsedSecs),
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Weight + reps
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatWeight(
                    widget.proposedSet.targetWeight.toDouble(),
                    unit,
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  ' ${weightUnitSuffix(unit)}',
                  style: TextStyle(fontSize: 14, color: colorScheme.tertiary),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '\u00B7',
                    style: TextStyle(
                      fontSize: 28,
                      color: colorScheme.tertiary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Text(
                  widget.proposedSet.isAmrap
                      ? 'AMRAP'
                      : '${widget.proposedSet.targetReps}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
                if (!widget.proposedSet.isAmrap)
                  Text(
                    ' reps',
                    style: TextStyle(fontSize: 14, color: colorScheme.tertiary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            PlateVisualization(
              weight: widget.proposedSet.targetWeight.toDouble(),
            ),
            const SizedBox(height: 12),

            // Rep picker + complete button
            Row(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: ListWheelScrollView.useDelegate(
                    controller: _scrollController,
                    itemExtent: 24,
                    magnification: 1.5,
                    useMagnifier: true,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.2,
                    perspective: 0.003,
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        final maxReps = widget.proposedSet.isAmrap
                            ? 30
                            : widget.proposedSet.targetReps;
                        if (index < 0 || index > maxReps) {
                          return null;
                        }
                        return Center(
                          child: Text(
                            '$index',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        );
                      },
                      childCount: widget.proposedSet.isAmrap
                          ? 31
                          : widget.proposedSet.targetReps + 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.proposedSet.isAmrap
                      ? 'AMRAP'
                      : 'good/${widget.proposedSet.targetReps}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => widget.onComplete(
                        _scrollController.selectedItem,
                        widget.proposedSet.targetWeight.toDouble(),
                      ),
                      child: const Text(
                        'Complete Set',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Skip warmup
            if (isWarmup && widget.onSkipWarmup != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onSkipWarmup,
                  child: Text(
                    'Skip Warmup',
                    style: TextStyle(fontSize: 12, color: colorScheme.tertiary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── NextUpBox ──────────────────────────────────────────────────────

class NextUpBox extends StatelessWidget {
  final ProposedSet nextSet;
  final VoidCallback onStart;
  final VoidCallback? onSkipWarmup;

  const NextUpBox({
    super.key,
    required this.nextSet,
    required this.onStart,
    this.onSkipWarmup,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: _AccentBox(
        accentColor: colorScheme.tertiary.withValues(alpha: 0.3),
        dashed: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT UP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 4),
            _NextSetInfo(set: nextSet),
            const SizedBox(height: 10),
            _ActionRow(
              label: 'Start Set',
              onAction: onStart,
              onSkipWarmup: nextSet.warmup ? onSkipWarmup : null,
            ),
          ],
        ),
      ),
    );
  }
}
