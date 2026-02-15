import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/group_next_up.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/plate_visualization.dart';
import '../widgets/workout_modals.dart';

String _fmt(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class WorkoutBottomBar extends StatefulWidget {
  const WorkoutBottomBar({super.key});

  @override
  State<WorkoutBottomBar> createState() => _WorkoutBottomBarState();
}

class _WorkoutBottomBarState extends State<WorkoutBottomBar> {
  bool _soundPlayed = false;
  int _prevRestSeconds = 0;

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    final soundProvider = context.read<SoundProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null || wp.isWorkoutEnded) {
      return const SizedBox.shrink();
    }

    // Sound on rest end
    final restSeconds = wp.restSecondsRemaining;
    if (_prevRestSeconds > 0 && restSeconds == 0 && !_soundPlayed) {
      _soundPlayed = true;
      soundProvider.playCurrentSound();
    }
    if (restSeconds > 0) {
      _soundPlayed = false;
    }
    _prevRestSeconds = restSeconds;

    final activeSetId = wp.activeSetId;
    final nextSet = wp.nextPendingSet;
    final isResting = wp.restingSet != null;

    final nowUnix = wp.now.millisecondsSinceEpoch ~/ 1000;
    final lastRestEnd = wp.lastRestEndTimestamp ?? 0;
    final isChatTime = !isResting &&
        activeSetId == null &&
        lastRestEnd > 0 &&
        lastRestEnd <= nowUnix &&
        nextSet != null;
    final chatElapsed = isChatTime ? nowUnix - lastRestEnd : 0;

    final allDone = wp.proposedSets.isNotEmpty &&
        wp.proposedSets.every((p) => wp.isSetDone(p.id)) &&
        activeSetId == null;

    final groupNextUp = computeGroupNextUp(mp.sessionStatus, auth.userId, nowUnix);

    // Determine if we're on the workout page
    final currentUri = GoRouterState.of(context).uri.toString();
    final isOnWorkoutPage = currentUri == '/';

    // Figure out state info
    String stateLabel;
    Color stateColor;
    String? timerText;
    Color? timerColor;
    ProposedSet? displaySet; // the set to show weight info for
    Widget actionButton = const SizedBox.shrink();

    if (allDone) {
      stateLabel = 'ALL SETS COMPLETE';
      stateColor = AppTheme.successFg;
      displaySet = null;
      actionButton = _BigButton(
        label: 'End Workout',
        onPressed: () => _endWorkout(context, wp),
      );
    } else if (activeSetId != null) {
      final proposed = wp.proposedSets.cast<ProposedSet?>().firstWhere(
        (p) => p!.id == activeSetId,
        orElse: () => null,
      );
      if (proposed == null) return const SizedBox.shrink();

      final activeCompleted = wp.completedSets.cast<CompletedSet?>().firstWhere(
        (c) => c!.proposedSetId == activeSetId && c.endedAt == Int64.ZERO,
        orElse: () => null,
      );
      final elapsedSecs = activeCompleted != null
          ? (wp.now.millisecondsSinceEpoch ~/ 1000) - activeCompleted.startedAt.toInt()
          : 0;

      stateLabel = proposed.warmup ? 'WARMUP' : 'LIFTING';
      stateColor = proposed.warmup ? const Color(0xFF3B82F6) : colorScheme.primary;
      timerText = _fmt(elapsedSecs);
      timerColor = colorScheme.tertiary;
      displaySet = proposed;
      actionButton = _RepButtons(
        targetReps: proposed.targetReps,
        onComplete: (reps) => wp.completeSet(activeSetId, reps, proposed.targetWeight.toDouble()),
        onSkipWarmup: proposed.warmup ? () => wp.skipWarmup(activeSetId) : null,
      );
    } else if (isResting) {
      stateLabel = 'RESTING';
      stateColor = const Color(0xFF3B82F6);
      timerText = _fmt(restSeconds);
      timerColor = null; // default
      displaySet = nextSet;
      actionButton = _BigButton(
        label: 'Start Early',
        onPressed: () {
          if (nextSet != null) wp.startSet(nextSet.id);
        },
        secondaryLabel: nextSet?.warmup == true ? 'Skip Warmup' : null,
        onSecondary: nextSet?.warmup == true ? () => wp.skipWarmup(nextSet!.id) : null,
      );
    } else if (isChatTime) {
      stateLabel = 'CHATTING';
      stateColor = const Color(0xFFF97316);
      timerText = '+${_fmt(chatElapsed)}';
      timerColor = const Color(0xFFF97316);
      displaySet = nextSet;
      actionButton = _BigButton(
        label: 'Start Set',
        onPressed: () => wp.startSet(nextSet.id),
        secondaryLabel: nextSet.warmup ? 'Skip Warmup' : null,
        onSecondary: nextSet.warmup ? () => wp.skipWarmup(nextSet.id) : null,
      );
    } else if (nextSet != null) {
      stateLabel = 'NEXT UP';
      stateColor = colorScheme.tertiary;
      displaySet = nextSet;
      actionButton = _BigButton(
        label: 'Start Set',
        onPressed: () => wp.startSet(nextSet.id),
        secondaryLabel: nextSet.warmup ? 'Skip Warmup' : null,
        onSecondary: nextSet.warmup ? () => wp.skipWarmup(nextSet.id) : null,
      );
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: !isOnWorkoutPage ? () => context.go('/') : null,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: state label + weight info on left, timer on right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: state + set info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: stateColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                stateLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: stateColor,
                                ),
                              ),
                            ],
                          ),
                          if (displaySet != null) ...[
                            const SizedBox(height: 4),
                            _SetWeightInfo(set: displaySet),
                          ],
                        ],
                      ),
                    ),
                    // Right: timer
                    if (timerText != null)
                      Text(
                        timerText,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: -2,
                          color: timerColor,
                        ),
                      ),
                  ],
                ),

                // Group next up info (multiplayer)
                if (groupNextUp != null && mp.participants.length > 1) ...[
                  const SizedBox(height: 6),
                  _GroupNextUpInfo(
                    data: groupNextUp,
                    now: wp.now,
                  ),
                ],

                // Row 2: full-width action button
                const SizedBox(height: 10),
                actionButton,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _endWorkout(BuildContext context, WorkoutProvider wp) async {
    final confirmed = await showEndWorkoutConfirmDialog(context);
    if (confirmed) {
      final workoutId = wp.workout!.id;
      await wp.endWorkout();
      if (context.mounted) {
        context.go('/workout/$workoutId/completed');
      }
    }
  }
}

// ─── Set weight info (left side of bottom bar) ───────────────────────

class _SetWeightInfo extends StatelessWidget {
  final ProposedSet set;

  const _SetWeightInfo({required this.set});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[set.exercise] ?? '?';

    return Row(
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
        const SizedBox(width: 8),
        Text(
          '${set.targetReps}\u00D7${set.targetWeight.toInt()}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          ' lb',
          style: TextStyle(fontSize: 11, color: colorScheme.tertiary),
        ),
        const SizedBox(width: 8),
        PlateVisualization(weight: set.targetWeight.toDouble()),
      ],
    );
  }
}

// ─── Group next up info ──────────────────────────────────────────────

class _GroupNextUpInfo extends StatelessWidget {
  final GroupNextUpData data;
  final DateTime now;

  const _GroupNextUpInfo({required this.data, required this.now});

  static const _purple = Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
    final remaining = data.restUntil - nowUnix;
    final isOverdue = remaining <= 0;
    final name = data.participant.user.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _purple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              data.isMe
                  ? "YOU'RE NEXT"
                  : 'NEXT: ${name.toUpperCase()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: _purple,
              ),
            ),
          ),
          if (data.nextSet != null) ...[
            Text(
              '${exerciseNames[data.nextSet!.exercise] ?? '?'} ${data.nextSet!.targetWeight.toInt()} lb',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _purple,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            isOverdue ? 'READY' : _fmt(remaining),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: _purple,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Big full-width action button ────────────────────────────────────

class _BigButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _BigButton({
    required this.label,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Rep buttons (for active set) ────────────────────────────────────

class _RepButtons extends StatelessWidget {
  final int targetReps;
  final void Function(int reps) onComplete;
  final VoidCallback? onSkipWarmup;

  const _RepButtons({
    required this.targetReps,
    required this.onComplete,
    this.onSkipWarmup,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rep buttons in a wrap
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(targetReps + 1, (n) {
            final isTarget = n == targetReps;
            return SizedBox(
              width: 52,
              height: 48,
              child: isTarget
                  ? FilledButton(
                      onPressed: () => onComplete(n),
                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        '$n',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => onComplete(n),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        '$n',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
            );
          }),
        ),
        if (onSkipWarmup != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: onSkipWarmup,
              child: Text(
                'Skip Warmup',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
