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
        onSkipWarmup: null,
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
          secondaryLabel: wp.canSkipWarmup(actionSet.id) ? 'Skip Warmup' : null,
          onSecondary: wp.canSkipWarmup(actionSet.id)
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
          secondaryLabel: displaySet != null && wp.canSkipWarmup(displaySet.id) ? 'Skip Warmup' : null,
          onSecondary: displaySet != null && wp.canSkipWarmup(displaySet.id)
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
        secondaryLabel: wp.canSkipWarmup(actionSet.id) ? 'Skip Warmup' : null,
        onSecondary: wp.canSkipWarmup(actionSet.id)
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
                // Row 1: Group status box
                if (mp.participants.length > 1) ...[
                  _buildGroupStatusBox(
                    context,
                    mp.sessionStatus,
                    auth.userId,
                    wp.now,
                  ),
                  const SizedBox(height: 8),
                ],

                // Row 2: Current user status box
                StatusBox(
                  sideLabel: 'YOU',
                  stateLabel: stateLabel,
                  color: stateColor,
                  timerText: timerText,
                  timerColor: timerColor,
                  set: displaySet,
                  isComplete: _isAllDoneState(stateValue),
                ),

                // Row 3: action + total time on one line
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 64,
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
    final error = Theme.of(context).colorScheme.error;
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    // "You're up next" takes priority over everything else — check it first so
    // it shows regardless of whether someone else is currently lifting.
    final nextUpUserId = status.nextUpUserId;
    if (nextUpUserId.isNotEmpty && nextUpUserId == myUserId) {
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

    // Find someone in the group who is active or next
    ParticipantStatus? groupActive;
    String groupState = '';
    String? groupTimer;
    Color? groupTimerColor;
    ProposedSet? groupSet;
    Color boxColor = purple;

    // Find another participant who is actively lifting. Prefer the server's
    // designated currentLifterId, but fall back to scanning all participants
    // for an active set — this handles simultaneous lifts where
    // currentLifterId == myUserId but someone else is also mid-set.
    final currentLifterId = status.currentlyLiftingUserId;
    final otherLifter = currentLifterId.isNotEmpty && currentLifterId != myUserId
        ? status.participants
            .cast<ParticipantStatus?>()
            .firstWhere((p) => p!.user.id == currentLifterId, orElse: () => null)
        : status.participants
            .cast<ParticipantStatus?>()
            .firstWhere(
              (p) =>
                  p!.user.id != myUserId &&
                  p.completedSets.any((c) => c.endedAt == Int64.ZERO),
              orElse: () => null,
            );

    if (otherLifter != null) {
      final active = otherLifter.completedSets
          .cast<CompletedSet?>()
          .firstWhere((c) => c!.endedAt == Int64.ZERO, orElse: () => null);
      final proposed = active == null
          ? null
          : otherLifter.proposedSets.cast<ProposedSet?>().firstWhere(
              (s) => s!.id == active.proposedSetId,
              orElse: () => null,
            );
      groupActive = otherLifter;
      groupState = proposed?.warmup == true ? 'Warmup' : 'Lifting';
      groupTimer = active != null
          ? _fmt(nowUnix - active.startedAt.toInt())
          : null;
      groupSet = proposed;
    }

    if (groupActive == null && nextUpUserId.isNotEmpty) {
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
          groupTimerColor = error;
          boxColor = error;
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

    // If the current user is lifting and no other participant state can be
    // determined yet, show a placeholder so the group section doesn't disappear
    // transiently the moment the user starts a set.
    if (groupActive == null && currentLifterId == myUserId) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: purple.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: purple.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.group, color: purple, size: 18),
            SizedBox(width: 8),
            Text(
              "Everyone's watching",
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
        if (secondaryLabel != null && onSecondary != null) ...[
          SizedBox(
            height: 64,
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
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SizedBox(
            height: 64,
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
      ],
    );
  }
}

// ─── Rep picker + complete button (for active set) ───────────────────

class _RepButtons extends StatefulWidget {
  final int targetReps;
  final void Function(int reps) onComplete;
  final VoidCallback? onSkipWarmup;

  const _RepButtons({
    required this.targetReps,
    required this.onComplete,
    this.onSkipWarmup,
  });

  @override
  State<_RepButtons> createState() => _RepButtonsState();
}

class _RepButtonsState extends State<_RepButtons> {
  late final FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController =
        FixedExtentScrollController(initialItem: widget.targetReps.clamp(0, 50));
  }

  @override
  void didUpdateWidget(_RepButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetReps != widget.targetReps) {
      _scrollController.jumpToItem(widget.targetReps.clamp(0, 50));
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Number scroll wheel
            Container(
              height: 64,
              width: 64,
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
                    if (index < 0 || index > 50) return null;
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
                  childCount: 51,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'good/${widget.targetReps}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            // Complete set button
            Expanded(
              child: SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: () =>
                      widget.onComplete(_scrollController.selectedItem),
                  child: const Text(
                    'Complete Set',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.onSkipWarmup != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: widget.onSkipWarmup,
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
