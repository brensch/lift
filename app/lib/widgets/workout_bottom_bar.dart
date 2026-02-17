import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_modals.dart';
import '../widgets/workout_status_box.dart';

String _fmt(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _fmtElapsed(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

bool _isAllDoneState(int state) =>
    state == WorkoutState.WORKOUT_STATE_ALL_DONE.value;
bool _isLiftingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_LIFTING.value;
bool _isRestingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_RESTING.value;
bool _isReadyState(int state) =>
    state == WorkoutState.WORKOUT_STATE_READY.value;

class WorkoutBottomBar extends StatelessWidget {
  const WorkoutBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Show bottom bar if there's an active workout, even if we are viewing history
    if (!wp.hasActiveWorkout) {
      return const SizedBox.shrink();
    }

    final stateSnapshot = wp.stateSnapshot;
    final stateValue =
        stateSnapshot?.state.value ??
        WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
    final nextSet = wp.nextPendingSet;
    final nowUnix = wp.now.millisecondsSinceEpoch ~/ 1000;
    final restUntil = stateSnapshot?.restUntil.toInt() ?? 0;
    final activeStartedAt = stateSnapshot?.activeStartedAt.toInt() ?? 0;
    final lastRestEnd = stateSnapshot?.lastRestEnd.toInt() ?? 0;
    final restSeconds = restUntil > 0
        ? (restUntil - nowUnix).clamp(0, 1 << 30)
        : 0;
    final workout = wp.activeWorkout;
    final elapsedSeconds = workout != null && workout.startTime != Int64.ZERO
        ? (wp.now.millisecondsSinceEpoch ~/ 1000) - workout.startTime.toInt()
        : 0;
    final elapsedText = _fmtElapsed(elapsedSeconds < 0 ? 0 : elapsedSeconds);

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

    if (_isAllDoneState(stateValue)) {
      stateLabel = 'All sets complete';
      stateColor = AppTheme.successFg;
      displaySet = null;
      actionButton = _BigButton(
        label: 'End Workout',
        onPressed: () => endWorkout(context),
      );
    } else if (_isLiftingState(stateValue)) {
      final proposed = stateSnapshot?.hasDisplaySet() == true
          ? stateSnapshot!.displaySet
          : null;
      if (proposed == null) return const SizedBox.shrink();
      final elapsedSecs = activeStartedAt > 0 ? (nowUnix - activeStartedAt) : 0;

      stateLabel = proposed.warmup ? 'Warmup' : 'Lifting';
      stateColor = proposed.warmup
          ? const Color(0xFF3B82F6)
          : colorScheme.primary;
      timerText = _fmt(elapsedSecs);
      timerColor = colorScheme.tertiary;
      displaySet = proposed;
      actionButton = _RepButtons(
        targetReps: proposed.targetReps,
        onComplete: (reps) =>
            wp.completeSet(proposed.id, reps, proposed.targetWeight.toDouble()),
        onSkipWarmup: proposed.warmup ? () => wp.skipWarmup(proposed.id) : null,
      );
    } else if (_isRestingState(stateValue)) {
      final hasExpiredRest =
          restUntil > 0 && restUntil <= nowUnix && nextSet != null;
      if (hasExpiredRest) {
        stateLabel = 'Yapping';
        stateColor = colorScheme.error;
        timerText = '-${_fmt(nowUnix - restUntil)}';
        timerColor = colorScheme.error;
        final ProposedSet actionSet = stateSnapshot?.hasDisplaySet() == true
            ? stateSnapshot!.displaySet
            : nextSet;
        displaySet = actionSet;
        actionButton = _BigButton(
          label: 'Start Set',
          onPressed: () => wp.startSet(actionSet.id),
          secondaryLabel: actionSet.warmup ? 'Skip Warmup' : null,
          onSecondary: actionSet.warmup
              ? () => wp.skipWarmup(actionSet.id)
              : null,
        );
      } else {
        stateLabel = 'Resting';
        stateColor = const Color(0xFF3B82F6);
        timerText = _fmt(restSeconds);
        timerColor = null; // default
        displaySet = stateSnapshot?.hasDisplaySet() == true
            ? stateSnapshot!.displaySet
            : nextSet;
        actionButton = _BigButton(
          label: 'Start Early',
          onPressed: () {
            if (displaySet != null) wp.startSet(displaySet.id);
          },
          secondaryLabel: displaySet?.warmup == true ? 'Skip Warmup' : null,
          onSecondary: displaySet?.warmup == true
              ? () => wp.skipWarmup(displaySet!.id)
              : null,
        );
      }
    } else if (_isReadyState(stateValue) || nextSet != null) {
      final isYapping =
          nextSet != null && lastRestEnd > 0 && lastRestEnd <= nowUnix;
      stateLabel = isYapping ? 'Yapping' : 'Next up';
      stateColor = isYapping ? colorScheme.error : colorScheme.tertiary;
      timerText = isYapping ? '-${_fmt(nowUnix - lastRestEnd)}' : null;
      timerColor = isYapping ? colorScheme.error : null;
      displaySet = stateSnapshot?.hasDisplaySet() == true
          ? stateSnapshot!.displaySet
          : nextSet;
      if (displaySet == null) return const SizedBox.shrink();
      final ProposedSet actionSet = displaySet;
      actionButton = _BigButton(
        label: 'Start Set',
        onPressed: () => wp.startSet(actionSet.id),
        secondaryLabel: actionSet.warmup ? 'Skip Warmup' : null,
        onSecondary: actionSet.warmup
            ? () => wp.skipWarmup(actionSet.id)
            : null,
      );
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: !isOnWorkoutPage
          ? () {
              context.go('/');
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            right: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
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
                  sideLabel: 'YOU',
                  stateLabel: stateLabel,
                  color: stateColor,
                  timerText: timerText,
                  timerColor: timerColor,
                  set: displaySet,
                  isComplete: _isAllDoneState(stateValue),
                ),

                // Row 3: Group status box
                if (mp.participants.length > 1) ...[
                  const SizedBox(height: 8),
                  _buildGroupStatusBox(
                    context,
                    mp.sessionStatus,
                    auth.userId,
                    wp.now,
                  ),
                ],

                // Row 3: action + total time on one line
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          elapsedText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: actionButton),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupStatusBox(
    BuildContext context,
    SessionStatus? status,
    String? myUserId,
    DateTime now,
  ) {
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

    final currentLifterId = status.currentlyLiftingUserId;
    if (currentLifterId.isNotEmpty && currentLifterId != myUserId) {
      final liftingParticipant = status.participants
          .cast<ParticipantStatus?>()
          .firstWhere((p) => p!.user.id == currentLifterId, orElse: () => null);
      if (liftingParticipant != null) {
        final active = liftingParticipant.completedSets
            .cast<CompletedSet?>()
            .firstWhere((c) => c!.endedAt == Int64.ZERO, orElse: () => null);
        final proposed = active == null
            ? null
            : liftingParticipant.proposedSets.cast<ProposedSet?>().firstWhere(
                (s) => s!.id == active.proposedSetId,
                orElse: () => null,
              );
        groupActive = liftingParticipant;
        groupState = proposed?.warmup == true ? 'Warmup' : 'Lifting';
        groupTimer = active != null
            ? _fmt(nowUnix - active.startedAt.toInt())
            : null;
        groupSet = proposed;
      }
    }

    if (groupActive == null) {
      final nextUpUserId = status.nextUpUserId;
      if (nextUpUserId.isNotEmpty && nextUpUserId == myUserId) {
        isMeNext = true;
      } else if (nextUpUserId.isNotEmpty) {
        final nextParticipant = status.participants
            .cast<ParticipantStatus?>()
            .firstWhere((p) => p!.user.id == nextUpUserId, orElse: () => null);
        if (nextParticipant != null) {
          groupActive = nextParticipant;
          final nextRestUntil = status.nextUpRestUntil.toInt() > 0
              ? status.nextUpRestUntil.toInt()
              : nextParticipant.restUntil.toInt();
          final remaining = nextRestUntil - nowUnix;
          if (remaining > 0) {
            groupState = 'Resting';
            groupTimer = _fmt(remaining);
          } else if (nextRestUntil > 0) {
            groupState = 'Yapping';
            groupTimer = '+${_fmt(nowUnix - nextRestUntil)}';
            groupTimerColor = orange;
          } else {
            groupState = 'Ready';
            groupTimer = 'Ready';
          }
          if (nextParticipant.hasNextUpSet()) {
            groupSet = nextParticipant.nextUpSet;
          } else if (status.hasNextUpSet()) {
            groupSet = status.nextUpSet;
          }
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
              "You're up next in the group",
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

    final name = groupActive.user.name;

    return StatusBox(
      sideLabel: 'GROUP',
      header: 'UP NEXT: $name',
      stateLabel: groupState,
      color: boxColor,
      timerText: groupTimer,
      timerColor: groupTimerColor,
      set: groupSet,
      showHeader: true,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => onComplete(n),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        '$n',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
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
                style: TextStyle(fontSize: 13, color: colorScheme.tertiary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
