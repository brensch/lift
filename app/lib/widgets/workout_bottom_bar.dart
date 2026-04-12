import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../logic/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/participant_ticker.dart';
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
    final latestHeartRate = wp.wearHeartRateSamples.isNotEmpty
        ? wp.wearHeartRateSamples.last
        : null;
    final heartRateText = latestHeartRate != null && latestHeartRate.bpm > 0
        ? '${latestHeartRate.bpm.round()}'
        : '--';

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
      stateColor = AppTheme.workoutLiftingFg;
      timerText = _fmt(elapsedSecs);
      timerColor = null;
      displaySet = proposed;
      actionButton = _RepButtons(
        targetReps: proposed.targetReps,
        isAmrap: proposed.isAmrap,
        onComplete: (reps) =>
            wp.completeSet(proposed.id, reps, proposed.targetWeight.toDouble()),
        onSkipWarmup: null,
      );
    } else if (_isRestingState(stateValue)) {
      final hasExpiredRest =
          restUntil > 0 && restUntil <= nowUnix && nextSet != null;
      if (hasExpiredRest) {
        stateLabel = 'Yapping';
        stateColor = AppTheme.workoutYappingFg;
        timerText = '-${_fmt(nowUnix - restUntil)}';
        timerColor = AppTheme.workoutYappingFg;
        final ProposedSet actionSet = stateSnapshot?.hasDisplaySet() == true
            ? stateSnapshot!.displaySet
            : nextSet;
        displaySet = actionSet;
        actionButton = _BigButton(
          label: 'Start Set',
          onPressed: () => wp.startSet(actionSet.id),
          secondaryLabel: wp.canSkipWarmup(actionSet.id) ? 'Skip' : null,
          onSecondary: wp.canSkipWarmup(actionSet.id)
              ? () => wp.skipWarmup(actionSet.id)
              : null,
        );
      } else {
        stateLabel = 'Resting';
        stateColor = AppTheme.workoutRestingFg;
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
          secondaryLabel: displaySet != null && wp.canSkipWarmup(displaySet.id)
              ? 'Skip'
              : null,
          onSecondary: displaySet != null && wp.canSkipWarmup(displaySet.id)
              ? () => wp.skipWarmup(displaySet!.id)
              : null,
        );
      }
    } else if (_isReadyState(stateValue) || nextSet != null) {
      final isYapping =
          nextSet != null && lastRestEnd > 0 && lastRestEnd <= nowUnix;
      stateLabel = isYapping ? 'Yapping' : 'Next up';
      stateColor = isYapping ? AppTheme.workoutYappingFg : colorScheme.tertiary;
      timerText = isYapping ? '-${_fmt(nowUnix - lastRestEnd)}' : null;
      timerColor = isYapping ? AppTheme.workoutYappingFg : null;
      displaySet = stateSnapshot?.hasDisplaySet() == true
          ? stateSnapshot!.displaySet
          : nextSet;
      if (displaySet == null) return const SizedBox.shrink();
      final ProposedSet actionSet = displaySet;
      actionButton = _BigButton(
        label: 'Start Set',
        onPressed: () => wp.startSet(actionSet.id),
        secondaryLabel: wp.canSkipWarmup(actionSet.id) ? 'Skip' : null,
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
                if (mp.participants.isNotEmpty) ...[
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
                  sideBadge: auth.profileEmoji,
                  stateLabel: stateLabel,
                  color: stateColor,
                  sideColor: profileColorFromHex(auth.profileColorHex),
                  timerText: timerText,
                  timerColor: timerColor,
                  set: displaySet,
                  isComplete: _isAllDoneState(stateValue),
                  sideLabelWidth: 44,
                ),

                // Row 3: action + total time on one line
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 64,
                      width: 84,
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  elapsedText,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurface,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.favorite,
                                size: 14,
                                color: Color(0xFFE11D48),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                heartRateText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurface,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
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
    final otherParticipants = status.participants
        .where((p) => p.user.id.isNotEmpty && p.user.id != myUserId)
        .toList(growable: false);

    if (otherParticipants.isEmpty) {
      return const SizedBox.shrink();
    }
    otherParticipants.sort((a, b) {
      final aStatus = describeParticipantStatus(a, now: now);
      final bStatus = describeParticipantStatus(b, now: now);
      final priorityCompare = bStatus.sortPriority.compareTo(
        aStatus.sortPriority,
      );
      if (priorityCompare != 0) return priorityCompare;
      return participantDisplayName(
        a,
      ).toLowerCase().compareTo(participantDisplayName(b).toLowerCase());
    });
    final featured = otherParticipants.first;
    final featuredStatus = describeParticipantStatus(featured, now: now);
    final sideLabel = _sideLabelName(participantDisplayName(featured));

    return StatusBox(
      sideLabel: sideLabel,
      sideBadge: participantProfileEmoji(featured),
      header: participantDisplayName(featured),
      stateLabel: featuredStatus.stateLabel,
      color: featuredStatus.stateColor,
      sideColor: participantProfileColor(featured),
      timerText: featuredStatus.timerText,
      timerColor: featuredStatus.timerColor,
      set: featuredStatus.proposedSet,
      showHeader: true,
      sideLabelWidth: 44,
    );
  }
}

String _sideLabelName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'GROUP';
  if (trimmed.length <= 10) return trimmed.toUpperCase();
  return '${trimmed.substring(0, 9).toUpperCase()}…';
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
  final bool isAmrap;
  final void Function(int reps) onComplete;
  final VoidCallback? onSkipWarmup;

  const _RepButtons({
    required this.targetReps,
    this.isAmrap = false,
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
    _scrollController = FixedExtentScrollController(
      initialItem: widget.targetReps.clamp(0, 50),
    );
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
              widget.isAmrap ? 'AMRAP' : 'good/${widget.targetReps}',
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
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                'Skip',
                style: TextStyle(fontSize: 13, color: colorScheme.tertiary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
