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

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

int _compareParticipantsByNextWorkout(
  ParticipantStatus a,
  ParticipantStatus b, {
  required int nowUnix,
}) {
  final aHasActiveSet =
      a.hasActiveSet ||
      a.completedSets.any((completed) => completed.endedAt == Int64.ZERO);
  final bHasActiveSet =
      b.hasActiveSet ||
      b.completedSets.any((completed) => completed.endedAt == Int64.ZERO);

  if (aHasActiveSet != bHasActiveSet) {
    return aHasActiveSet ? -1 : 1;
  }

  final aScheduled = participantScheduledStartUnix(a, nowUnix: nowUnix);
  final bScheduled = participantScheduledStartUnix(b, nowUnix: nowUnix);
  if (aScheduled != null && bScheduled != null && aScheduled != bScheduled) {
    return aScheduled.compareTo(bScheduled);
  }
  if (aScheduled != null && bScheduled == null) return -1;
  if (aScheduled == null && bScheduled != null) return 1;

  final nameCompare = participantDisplayName(
    a,
  ).toLowerCase().compareTo(participantDisplayName(b).toLowerCase());
  if (nameCompare != 0) return nameCompare;
  return a.user.id.compareTo(b.user.id);
}

int _compareParticipantsStable(ParticipantStatus a, ParticipantStatus b) {
  final nameCompare = participantDisplayName(
    a,
  ).toLowerCase().compareTo(participantDisplayName(b).toLowerCase());
  if (nameCompare != 0) return nameCompare;
  return a.user.id.compareTo(b.user.id);
}

/// Returns the userId of whoever is "next to lift" across all session members.
/// Tiebreak: earliest scheduledStart, then lexicographic userId.
String? _computeNextToLiftUserId({
  required String? myUserId,
  required List<ParticipantStatus> others,
  required int nowUnix,
  required int stateValue,
  required int restUntil,
  required int lastRestEnd,
  required ProposedSet? nextSet,
}) {
  String? bestId;
  int? bestStart;

  bool isCandidate(String uid, int start) {
    final b = bestId;
    final bs = bestStart;
    if (b == null || bs == null) return true;
    if (start != bs) return start < bs;
    return uid.compareTo(b) < 0;
  }

  for (final p in others) {
    final start = participantScheduledStartUnix(p, nowUnix: nowUnix);
    if (start == null) continue;
    if (isCandidate(p.user.id, start)) {
      bestId = p.user.id;
      bestStart = start;
    }
  }

  if (myUserId != null && myUserId.isNotEmpty) {
    final myStart =
        !_isLiftingState(stateValue) &&
            !_isAllDoneState(stateValue) &&
            nextSet != null
        ? (restUntil > 0
              ? restUntil
              : (lastRestEnd > 0 ? lastRestEnd : nowUnix))
        : null;
    if (myStart != null && isCandidate(myUserId, myStart)) {
      bestId = myUserId;
      bestStart = myStart;
    }
  }

  return bestId;
}

// ─── WorkoutBottomBar ─────────────────────────────────────────────────────────

class WorkoutBottomBar extends StatefulWidget {
  const WorkoutBottomBar({super.key});

  @override
  State<WorkoutBottomBar> createState() => _WorkoutBottomBarState();
}

class _WorkoutBottomBarState extends State<WorkoutBottomBar>
    with SingleTickerProviderStateMixin {
  // How many pixels the participant panel slides into the current-user card
  // before it is fully hidden behind it.  Should match (or slightly exceed)
  // the StatusBox border-radius so the cards visually tuck under the corner.
  static const double _overlap = 16.0;
  static const double _currentUserTopInset = 4.0;
  static const double _handleSlotHeight = 24.0;
  static const double _handleThickness = 4.0;

  // 1.0 = fully expanded, 0.0 = collapsed.  Starts expanded.
  late final AnimationController _animation;

  // Used to measure the natural height of the panel content so drag
  // movement maps pixel-for-pixel to the animation value.
  final _panelKey = GlobalKey();
  double _panelHeight = 200.0; // fallback until measured
  bool _isDraggingPanel = false;

  double get _panelDragRange =>
      (_panelHeight - _collapsedPeekHeight).clamp(1.0, double.infinity);

  double get _handleToCardGap => (_handleSlotHeight - _handleThickness) / 2;
  // Preserve the original collapsed resting position for the handle, but
  // fully hide the participant layer at the exact collapsed endpoint.
  double get _collapsedPeekHeight => _handleToCardGap;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _toggle() {
    final target = _animation.value >= 0.5 ? 0.0 : 1.0;
    _animation.animateTo(
      target,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDraggingPanel) {
      setState(() {
        _isDraggingPanel = true;
      });
    }
    // Dragging DOWN (positive dy) collapses; UP (negative dy) expands.
    final delta = -(d.primaryDelta ?? d.delta.dy) / _panelDragRange;
    _animation.value = (_animation.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_isDraggingPanel) {
      setState(() {
        _isDraggingPanel = false;
      });
    }
    final vel = d.primaryVelocity ?? 0;
    final double target;
    if (vel > 300) {
      target = 0.0;
    } else if (vel < -300) {
      target = 1.0;
    } else {
      target = _animation.value >= 0.5 ? 1.0 : 0.0;
    }
    _animation.animateTo(
      target,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 250),
    );
  }

  // Remeasure the panel's natural height every frame while it is rendered.
  // ClipRect+Align still lays out the child at full size, so the GlobalKey
  // always reports the natural (uncollapsed) height.
  void _measurePanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.size.height > 0) {
        _panelHeight = box.size.height;
      }
    });
  }

  Future<void> _showAllParticipantsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer3<WorkoutProvider, MultiplayerProvider, AuthProvider>(
          builder: (context, wp, mp, auth, _) {
            return ValueListenableBuilder<DateTime>(
              valueListenable: wp.clock,
              builder: (context, now, _) {
                final colorScheme = Theme.of(sheetContext).colorScheme;
                final stateSnapshot = wp.stateSnapshot;
                final stateValue =
                    stateSnapshot?.state.value ??
                    WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
                final nextSet = wp.nextPendingSet;
                final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
                final restUntil = stateSnapshot?.restUntil.toInt() ?? 0;
                final activeStartedAt =
                    stateSnapshot?.activeStartedAt.toInt() ?? 0;
                final lastRestEnd = stateSnapshot?.lastRestEnd.toInt() ?? 0;
                final restSeconds = restUntil > 0
                    ? (restUntil - nowUnix).clamp(0, 1 << 30)
                    : 0;

                String stateLabel;
                Color stateColor;
                String? timerText;
                Color? timerColor;
                ProposedSet? displaySet;

                if (_isAllDoneState(stateValue)) {
                  stateLabel = 'All sets complete';
                  stateColor = AppTheme.successFg;
                  displaySet = null;
                } else if (_isLiftingState(stateValue)) {
                  final proposed = stateSnapshot?.hasDisplaySet() == true
                      ? stateSnapshot!.displaySet
                      : null;
                  stateLabel = proposed?.warmup == true ? 'Warmup' : 'Lifting';
                  stateColor = AppTheme.workoutLiftingFg;
                  timerText = _fmt(
                    activeStartedAt > 0 ? (nowUnix - activeStartedAt) : 0,
                  );
                  displaySet = proposed;
                } else if (_isRestingState(stateValue)) {
                  final hasExpiredRest =
                      restUntil > 0 && restUntil <= nowUnix && nextSet != null;
                  if (hasExpiredRest) {
                    stateLabel = 'Yapping';
                    stateColor = AppTheme.workoutYappingFg;
                    timerText = _fmt(nowUnix - restUntil);
                    timerColor = AppTheme.workoutYappingFg;
                    displaySet = stateSnapshot?.hasDisplaySet() == true
                        ? stateSnapshot!.displaySet
                        : nextSet;
                  } else {
                    stateLabel = 'Resting';
                    stateColor = AppTheme.workoutRestingFg;
                    timerText = _fmt(restSeconds);
                    displaySet = stateSnapshot?.hasDisplaySet() == true
                        ? stateSnapshot!.displaySet
                        : nextSet;
                  }
                } else if (_isReadyState(stateValue) || nextSet != null) {
                  final isYapping =
                      nextSet != null &&
                      lastRestEnd > 0 &&
                      lastRestEnd <= nowUnix;
                  stateLabel = isYapping ? 'Yapping' : 'Next up';
                  stateColor = isYapping
                      ? AppTheme.workoutYappingFg
                      : colorScheme.tertiary;
                  timerText = isYapping ? _fmt(nowUnix - lastRestEnd) : null;
                  timerColor = isYapping ? AppTheme.workoutYappingFg : null;
                  displaySet = stateSnapshot?.hasDisplaySet() == true
                      ? stateSnapshot!.displaySet
                      : nextSet;
                } else {
                  stateLabel = 'Workout';
                  stateColor = colorScheme.tertiary;
                  displaySet = null;
                }

                final others =
                    mp.participants
                        .where(
                          (p) =>
                              p.user.id.isNotEmpty && p.user.id != auth.userId,
                        )
                        .toList()
                      ..sort(_compareParticipantsStable);

                final nextToLiftUserId = _computeNextToLiftUserId(
                  myUserId: auth.userId,
                  others: others,
                  nowUnix: nowUnix,
                  stateValue: stateValue,
                  restUntil: restUntil,
                  lastRestEnd: lastRestEnd,
                  nextSet: nextSet,
                );
                final iAmNextToLift = nextToLiftUserId == auth.userId;

                return DraggableScrollableSheet(
                  initialChildSize: 0.82,
                  minChildSize: 0.45,
                  maxChildSize: 0.94,
                  expand: false,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                24,
                              ),
                              children: [
                                _HorizontalShaker(
                                  active: iAmNextToLift,
                                  child: StatusBox(
                                    sideLabel: 'YOU',
                                    sideBadge: normalizedProfileEmoji(
                                      auth.profileEmoji,
                                    ),
                                    header: 'You',
                                    showHeader: true,
                                    headerTrailing: iAmNextToLift
                                        ? const _RainbowShimmerText(
                                            text: 'next to schlift',
                                          )
                                        : null,
                                    stateLabel: stateLabel,
                                    color: stateColor,
                                    sideColor: profileColorFromHex(
                                      auth.profileColorHex,
                                    ),
                                    timerText: timerText,
                                    timerColor: timerColor,
                                    set: displaySet,
                                    isComplete: _isAllDoneState(stateValue),
                                    sideLabelWidth: 44,
                                  ),
                                ),
                                if (others.isNotEmpty)
                                  const SizedBox(height: 8),
                                for (var i = 0; i < others.length; i++) ...[
                                  _SessionMemberCard(
                                    name: participantDisplayName(others[i]),
                                    emoji: participantProfileEmoji(others[i]),
                                    profileColor: participantProfileColor(
                                      others[i],
                                    ),
                                    status: describeParticipantStatus(
                                      others[i],
                                      now: now,
                                    ),
                                    isNextToLift:
                                        nextToLiftUserId == others[i].user.id,
                                    shakeActive:
                                        nextToLiftUserId == others[i].user.id,
                                    onTap: () => showParticipantWorkoutModal(
                                      sheetContext,
                                      others[i],
                                    ),
                                  ),
                                  if (i < others.length - 1)
                                    const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (!wp.hasActiveWorkout) return const SizedBox.shrink();
    return ValueListenableBuilder<DateTime>(
      valueListenable: wp.clock,
      builder: (context, now, _) {
        final stateSnapshot = wp.stateSnapshot;
        final stateValue =
            stateSnapshot?.state.value ??
            WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
        final nextSet = wp.nextPendingSet;
        final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
        final restUntil = stateSnapshot?.restUntil.toInt() ?? 0;
        final activeStartedAt = stateSnapshot?.activeStartedAt.toInt() ?? 0;
        final lastRestEnd = stateSnapshot?.lastRestEnd.toInt() ?? 0;
        final restSeconds = restUntil > 0
            ? (restUntil - nowUnix).clamp(0, 1 << 30)
            : 0;
        final workout = wp.activeWorkout;
        final elapsedSeconds =
            workout != null && workout.startTime != Int64.ZERO
            ? (now.millisecondsSinceEpoch ~/ 1000) - workout.startTime.toInt()
            : 0;
        final elapsedText = _fmtElapsed(
          elapsedSeconds < 0 ? 0 : elapsedSeconds,
        );
        final latestHeartRate = wp.wearHeartRateSamples.isNotEmpty
            ? wp.wearHeartRateSamples.last
            : null;
        final heartRateText = latestHeartRate != null && latestHeartRate.bpm > 0
            ? '${latestHeartRate.bpm.round()}'
            : '--';

        final currentUri = GoRouterState.of(context).uri.toString();
        final isOnWorkoutPage = currentUri == '/';

        // ── Current-user state ────────────────────────────────────────────────────
        String stateLabel;
        Color stateColor;
        String? timerText;
        Color? timerColor;
        ProposedSet? displaySet;
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
          final elapsedSecs = activeStartedAt > 0
              ? (nowUnix - activeStartedAt)
              : 0;
          stateLabel = proposed.warmup ? 'Warmup' : 'Lifting';
          stateColor = AppTheme.workoutLiftingFg;
          timerText = _fmt(elapsedSecs);
          displaySet = proposed;
          actionButton = _RepButtons(
            targetReps: proposed.targetReps,
            isAmrap: proposed.isAmrap,
            onComplete: (reps) => wp.completeSet(
              proposed.id,
              reps,
              proposed.targetWeight.toDouble(),
            ),
            onSkipWarmup: null,
          );
        } else if (_isRestingState(stateValue)) {
          final hasExpiredRest =
              restUntil > 0 && restUntil <= nowUnix && nextSet != null;
          if (hasExpiredRest) {
            stateLabel = 'Yapping';
            stateColor = AppTheme.workoutYappingFg;
            timerText = _fmt(nowUnix - restUntil);
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
            final restingSet = stateSnapshot?.hasDisplaySet() == true
                ? stateSnapshot!.displaySet
                : nextSet;
            displaySet = restingSet;
            actionButton = _BigButton(
              label: 'Start Early',
              onPressed: () {
                if (restingSet != null) wp.startSet(restingSet.id);
              },
              secondaryLabel:
                  restingSet != null && wp.canSkipWarmup(restingSet.id)
                  ? 'Skip'
                  : null,
              onSecondary: restingSet != null && wp.canSkipWarmup(restingSet.id)
                  ? () => wp.skipWarmup(restingSet.id)
                  : null,
            );
          }
        } else if (_isReadyState(stateValue) || nextSet != null) {
          final isYapping =
              nextSet != null && lastRestEnd > 0 && lastRestEnd <= nowUnix;
          stateLabel = isYapping ? 'Yapping' : 'Next up';
          stateColor = isYapping
              ? AppTheme.workoutYappingFg
              : colorScheme.tertiary;
          timerText = isYapping ? _fmt(nowUnix - lastRestEnd) : null;
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

        // ── Session state ─────────────────────────────────────────────────────────
        final others =
            mp.participants
                .where((p) => p.user.id.isNotEmpty && p.user.id != auth.userId)
                .toList()
              ..sort(_compareParticipantsStable);
        final inSession = others.isNotEmpty;
        final visibleOthers = others.length > 4
            ? (List<ParticipantStatus>.from(others)..sort(
                    (a, b) => _compareParticipantsByNextWorkout(
                      a,
                      b,
                      nowUnix: nowUnix,
                    ),
                  ))
                  .take(4)
                  .toList(growable: false)
            : others;
        final hiddenOtherCount = (others.length - visibleOthers.length).clamp(
          0,
          1 << 30,
        );

        final nextToLiftUserId = inSession
            ? _computeNextToLiftUserId(
                myUserId: auth.userId,
                others: others,
                nowUnix: nowUnix,
                stateValue: stateValue,
                restUntil: restUntil,
                lastRestEnd: lastRestEnd,
                nextSet: nextSet,
              )
            : null;

        final iAmNextToLift = inSession && nextToLiftUserId == auth.userId;

        // Remeasure the panel height so drag stays pixel-accurate.
        if (inSession) _measurePanel();

        return GestureDetector(
          // Tapping anywhere on the bar navigates to workout page when elsewhere.
          onTap: !isOnWorkoutPage ? () => context.go('/') : null,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
                left: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
                right: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (inSession)
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: isOnWorkoutPage
                                ? _toggle
                                : () => context.go('/'),
                            child: SizedBox(
                              height: _handleSlotHeight,
                              child: AnimatedBuilder(
                                animation: _animation,
                                builder: (_, __) => Center(
                                  child: _DragHandle(
                                    isExpanded: _animation.value >= 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Other participants panel — follows the finger in real time.
                          // ClipRect+Align lays out the child at its natural size (so the
                          // GlobalKey always reports the true height) but clips it to the
                          // animated fraction of that height.
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              final collapsedFactor =
                                  (_collapsedPeekHeight / _panelHeight).clamp(
                                    0.0,
                                    1.0,
                                  );
                              final heightFactor =
                                  collapsedFactor +
                                  ((1 - collapsedFactor) * _animation.value);
                              return ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: heightFactor,
                                  child: IgnorePointer(
                                    ignoring: _animation.value <= 0.001,
                                    child: Opacity(
                                      opacity: _animation.value <= 0.001
                                          ? 0
                                          : 1,
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              key: _panelKey,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                _overlap - _currentUserTopInset,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (hiddenOtherCount > 0) ...[
                                    _MoreParticipantsCard(
                                      hiddenCount: hiddenOtherCount,
                                      onTap: isOnWorkoutPage
                                          ? _showAllParticipantsSheet
                                          : () => context.go('/'),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  for (final p in visibleOthers) ...[
                                    _SessionMemberCard(
                                      name: participantDisplayName(p),
                                      emoji: participantProfileEmoji(p),
                                      profileColor: participantProfileColor(p),
                                      status: describeParticipantStatus(
                                        p,
                                        now: now,
                                      ),
                                      isNextToLift:
                                          nextToLiftUserId == p.user.id,
                                      shakeActive:
                                          !_isDraggingPanel &&
                                          nextToLiftUserId == p.user.id,
                                      onTap: isOnWorkoutPage
                                          ? () => showParticipantWorkoutModal(
                                              context,
                                              p,
                                            )
                                          : () => context.go('/'),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Current-user action bar — always visible ──────────────────
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final overlap = inSession ? _overlap : 0.0;
                      return Transform.translate(
                        offset: Offset(0, -overlap),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        inSession ? _currentUserTopInset : 20,
                        20,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HorizontalShaker(
                            active: iAmNextToLift && !_isDraggingPanel,
                            child: StatusBox(
                              sideLabel: 'YOU',
                              sideBadge: auth.profileEmoji,
                              // In multiplayer show 'You' header so the rainbow
                              // "next to lift" label has a home.
                              header: inSession ? 'You' : null,
                              showHeader: inSession,
                              headerTrailing: iAmNextToLift
                                  ? const _RainbowShimmerText(
                                      text: 'next to schlift',
                                    )
                                  : null,
                              stateLabel: stateLabel,
                              color: stateColor,
                              sideColor: profileColorFromHex(
                                auth.profileColorHex,
                              ),
                              timerText: timerText,
                              timerColor: timerColor,
                              set: displaySet,
                              isComplete: _isAllDoneState(stateValue),
                              sideLabelWidth: 44,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _TimerHeartBox(
                                elapsedText: elapsedText,
                                heartRateText: heartRateText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: actionButton),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Drag handle ──────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  final bool isExpanded;
  const _DragHandle({required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: _WorkoutBottomBarState._handleThickness,
      decoration: BoxDecoration(
        color: colorScheme.onSecondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Session member card ──────────────────────────────────────────────────────

class _SessionMemberCard extends StatelessWidget {
  final String name;
  final String? emoji;
  final Color profileColor;
  final ParticipantVisualStatus status;
  final bool isNextToLift;
  final bool shakeActive;
  final VoidCallback? onTap;

  const _SessionMemberCard({
    required this.name,
    this.emoji,
    required this.profileColor,
    required this.status,
    required this.isNextToLift,
    required this.shakeActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = StatusBox(
      sideLabel: name,
      sideBadge: emoji,
      header: name,
      showHeader: true,
      headerTrailing: isNextToLift
          ? const _RainbowShimmerText(text: 'next to schlift')
          : null,
      stateLabel: status.stateLabel,
      color: status.stateColor,
      sideColor: profileColor,
      timerText: status.timerText,
      timerColor: status.timerColor,
      set: status.proposedSet,
      isComplete: status.isComplete,
      sideLabelWidth: 44,
    );

    final shaking = _HorizontalShaker(active: shakeActive, child: card);

    if (onTap == null) return shaking;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: shaking,
      ),
    );
  }
}

class _MoreParticipantsCard extends StatelessWidget {
  final int hiddenCount;
  final VoidCallback? onTap;

  const _MoreParticipantsCard({required this.hiddenCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.expand_less_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$hiddenCount more',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// ─── Rainbow shimmer text ─────────────────────────────────────────────────────

class _RainbowShimmerText extends StatefulWidget {
  final String text;
  const _RainbowShimmerText({required this.text});

  @override
  State<_RainbowShimmerText> createState() => _RainbowShimmerTextState();
}

class _RainbowShimmerTextState extends State<_RainbowShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
            stops: const [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
            begin: Alignment(-2.0 + 4 * t, 0),
            end: Alignment(0.0 + 4 * t, 0),
            tileMode: TileMode.repeated,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: child!,
        );
      },
      child: Text(
        widget.text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: Colors.white, // overridden by ShaderMask
        ),
      ),
    );
  }
}

// ─── Horizontal shake wrapper ─────────────────────────────────────────────────

class _HorizontalShaker extends StatefulWidget {
  final Widget child;
  final bool active;
  const _HorizontalShaker({required this.child, required this.active});

  @override
  State<_HorizontalShaker> createState() => _HorizontalShakerState();
}

class _HorizontalShakerState extends State<_HorizontalShaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _cycling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.active) _startCycle();
  }

  @override
  void didUpdateWidget(_HorizontalShaker old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _startCycle();
  }

  Future<void> _startCycle() async {
    if (_cycling) return;
    _cycling = true;
    while (mounted && widget.active) {
      await Future.delayed(const Duration(seconds: 4));
      if (mounted && widget.active) await _controller.forward(from: 0);
    }
    _cycling = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(_animation.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── Timer + heart rate box ───────────────────────────────────────────────────

class _TimerHeartBox extends StatelessWidget {
  final String elapsedText;
  final String heartRateText;
  const _TimerHeartBox({
    required this.elapsedText,
    required this.heartRateText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      width: 84,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 14, color: colorScheme.tertiary),
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
              const Icon(Icons.favorite, size: 14, color: Color(0xFFE11D48)),
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
    );
  }
}

// ─── Big full-width action button ─────────────────────────────────────────────

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

// ─── Rep picker + complete button ─────────────────────────────────────────────

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
