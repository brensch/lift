import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';
import '../logic/group_next_up.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_modals.dart';
import '../widgets/workout_status_box.dart';

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
  void didUpdateWidget(covariant WorkoutBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the key changes (new workout), reset internal state
    _soundPlayed = false;
    _prevRestSeconds = 0;
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    final soundProvider = context.read<SoundProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Show bottom bar if there's an active workout, even if we are viewing history
    if (!wp.hasActiveWorkout) {
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

    final allDone = wp.activeProposedSets.isNotEmpty &&
        wp.activeProposedSets.every((p) => wp.isSetDone(p.id)) &&
        activeSetId == null;

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
      final proposed = wp.activeProposedSets.cast<ProposedSet?>().firstWhere(
        (p) => p!.id == activeSetId,
        orElse: () => null,
      );
      if (proposed == null) return const SizedBox.shrink();

      final activeCompleted = wp.activeCompletedSets.cast<CompletedSet?>().firstWhere(
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
      onTap: !isOnWorkoutPage ? () {
        context.go('/');
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            right: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Current user status box
                StatusBox(
                  label: 'NEXT FOR YOU ($stateLabel)',
                  color: stateColor,
                  timerText: timerText,
                  timerColor: timerColor,
                  set: displaySet,
                  isComplete: allDone,
                ),

                // Row 2: Group status box
                if (mp.participants.length > 1) ...[
                  const SizedBox(height: 8),
                  _buildGroupStatusBox(context, mp.sessionStatus, auth.userId, wp.now),
                ],

                // Row 3: full-width action button
                const SizedBox(height: 12),
                actionButton,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupStatusBox(BuildContext context, SessionStatus? status, String? myUserId, DateTime now) {
    if (status == null) return const SizedBox.shrink();
    const purple = Color(0xFF9333EA);
    const orange = Color(0xFFF97316);
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    // Find someone in the group who is active or next
    ParticipantStatus? groupActive;
    String groupState = '';
    String? groupTimer;
    Color? groupTimerColor;
    ProposedSet? groupSet;
    Color boxColor = purple;
    bool isMeNext = false;

    for (final p in status.participants) {
      if (p.user.id == myUserId) continue;

      // Check if lifting
      final active = p.completedSets.cast<CompletedSet?>().firstWhere(
            (c) => c!.endedAt == Int64.ZERO,
            orElse: () => null,
          );

      if (active != null) {
        final proposed = p.proposedSets.cast<ProposedSet?>().firstWhere(
              (s) => s!.id == active.proposedSetId,
              orElse: () => null,
            );
        groupActive = p;
        groupState = proposed?.warmup == true ? 'WARMUP' : 'LIFTING';
        groupTimer = _fmt(nowUnix - active.startedAt.toInt());
        groupSet = proposed;
        break;
      }
    }

    if (groupActive == null) {
      // Nobody is lifting, find the next one up using the logic
      final nextUp = computeGroupNextUp(status, myUserId, nowUnix);
      if (nextUp != null) {
        if (nextUp.isMe) {
          isMeNext = true;
        } else {
          groupActive = nextUp.participant;
          final remaining = nextUp.restUntil - nowUnix;
          if (remaining > 0) {
            groupState = 'RESTING';
            groupTimer = _fmt(remaining);
          } else if (nextUp.restUntil > 0) {
            groupState = 'CHATTING';
            groupTimer = '+${_fmt(nowUnix - nextUp.restUntil)}';
            groupTimerColor = orange;
          } else {
            groupState = 'READY';
            groupTimer = 'READY';
          }
          groupSet = nextUp.nextSet;
        }
      }
    }

    if (isMeNext) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: purple.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: purple.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: purple, size: 18),
            SizedBox(width: 8),
            Text(
              "YOU'RE UP NEXT IN THE GROUP",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: purple,
              ),
            ),
          ],
        ),
      );
    }

    if (groupActive == null) return const SizedBox.shrink();

    final name = groupActive.user.name.toUpperCase();
    final label = 'NEXT FOR GROUP: $name ($groupState)';

    return StatusBox(
      label: label,
      color: boxColor,
      timerText: groupTimer,
      timerColor: groupTimerColor,
      set: groupSet,
    );
  }

  Future<void> _endWorkout(BuildContext context, WorkoutProvider wp) async {
    final confirmed = await showEndWorkoutConfirmDialog(context);
    if (confirmed) {
      final workoutId = wp.workout!.id;
      await wp.endWorkout();
      if (context.mounted) {
        final mp = context.read<MultiplayerProvider>();
        if (mp.isInSession) {
          await mp.leaveSession();
        }
        context.push('/workout/$workoutId/completed');
      }
    }
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
