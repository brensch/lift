import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../gen/workout/v1/group.pb.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../logic/user_profile.dart';
import '../../theme/app_theme.dart';
import '../participant_ticker.dart';
import '../dialogs/end_workout_dialog.dart';
import '../dialogs/participant_workout_modal.dart';
import '../workout_status_box.dart';
import '../../logic/session_state.dart';
import '../common/horizontal_shaker.dart';
import '../common/rainbow_shimmer_text.dart';
import 'bar_controls.dart';
import 'session_cards.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

  // 1.0 = fully expanded, 0.0 = collapsed.  Starts expanded.
  late final AnimationController _animation;

  // Used to measure the natural height of the panel content so drag
  // movement maps pixel-for-pixel to the animation value.
  final _panelKey = GlobalKey();
  double _panelHeight = 200.0; // fallback until measured
  bool _isDraggingPanel = false;

  double get _panelDragRange =>
      (_panelHeight - _collapsedPeekHeight).clamp(1.0, double.infinity);

  double get _handleToCardGap => (_handleSlotHeight - DragHandle.thickness) / 2;
  // Preserve the original collapsed resting position for the handle, but
  // fully hide the participant layer at the exact collapsed endpoint.
  double get _collapsedPeekHeight => _handleToCardGap;

  Widget _buildPanelDragTarget({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: child,
    );
  }

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

                if (isAllDoneState(stateValue)) {
                  stateLabel = 'All sets complete';
                  stateColor = AppTheme.successFg;
                  displaySet = null;
                } else if (isLiftingState(stateValue)) {
                  final proposed = stateSnapshot?.hasDisplaySet() == true
                      ? stateSnapshot!.displaySet
                      : null;
                  stateLabel = proposed?.warmup == true ? 'Warmup' : 'Lifting';
                  stateColor = AppTheme.workoutLiftingFg;
                  timerText = formatRestClock(
                    activeStartedAt > 0 ? (nowUnix - activeStartedAt) : 0,
                  );
                  displaySet = proposed;
                } else if (isRestingState(stateValue)) {
                  final hasExpiredRest =
                      restUntil > 0 && restUntil <= nowUnix && nextSet != null;
                  if (hasExpiredRest) {
                    stateLabel = 'Yapping';
                    stateColor = AppTheme.workoutYappingFg;
                    timerText = formatRestClock(nowUnix - restUntil);
                    timerColor = AppTheme.workoutYappingFg;
                    displaySet = stateSnapshot?.hasDisplaySet() == true
                        ? stateSnapshot!.displaySet
                        : nextSet;
                  } else {
                    stateLabel = 'Resting';
                    stateColor = AppTheme.workoutRestingFg;
                    timerText = formatRestClock(restSeconds);
                    displaySet = stateSnapshot?.hasDisplaySet() == true
                        ? stateSnapshot!.displaySet
                        : nextSet;
                  }
                } else if (isReadyState(stateValue) || nextSet != null) {
                  final isYapping =
                      nextSet != null &&
                      lastRestEnd > 0 &&
                      lastRestEnd <= nowUnix;
                  stateLabel = isYapping ? 'Yapping' : 'Next up';
                  stateColor = isYapping
                      ? AppTheme.workoutYappingFg
                      : colorScheme.tertiary;
                  timerText = isYapping ? formatRestClock(nowUnix - lastRestEnd) : null;
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
                      ..sort(compareParticipantsStable);

                final nextToLiftUserId = computeNextToLiftUserId(
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
                        color: AppTheme.sheetColor(sheetContext),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.radiusLg),
                        ),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Center(child: AppTheme.sheetHandle(sheetContext)),
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
                                HorizontalShaker(
                                  active: iAmNextToLift,
                                  child: StatusBox(
                                    sideLabel: 'YOU',
                                    sideBadge: normalizedProfileEmoji(
                                      auth.profileEmoji,
                                    ),
                                    header: 'You',
                                    showHeader: true,
                                    headerTrailing: iAmNextToLift
                                        ? const RainbowShimmerText(
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
                                    isComplete: isAllDoneState(stateValue),
                                    sideLabelWidth: 44,
                                  ),
                                ),
                                if (others.isNotEmpty)
                                  const SizedBox(height: 8),
                                for (var i = 0; i < others.length; i++) ...[
                                  SessionMemberCard(
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
        final elapsedText = formatElapsedClock(
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

        if (isAllDoneState(stateValue)) {
          stateLabel = 'All sets complete';
          stateColor = AppTheme.successFg;
          displaySet = null;
          actionButton = BigButton(
            label: 'End Workout',
            onPressed: () => endWorkout(context),
          );
        } else if (isLiftingState(stateValue)) {
          final proposed = stateSnapshot?.hasDisplaySet() == true
              ? stateSnapshot!.displaySet
              : null;
          if (proposed == null) return const SizedBox.shrink();
          final elapsedSecs = activeStartedAt > 0
              ? (nowUnix - activeStartedAt)
              : 0;
          stateLabel = proposed.warmup ? 'Warmup' : 'Lifting';
          stateColor = AppTheme.workoutLiftingFg;
          timerText = formatRestClock(elapsedSecs);
          displaySet = proposed;
          actionButton = RepButtons(
            targetReps: proposed.targetReps,
            isAmrap: proposed.isAmrap,
            onComplete: (reps) => wp.completeSet(
              proposed.id,
              reps,
              proposed.targetWeight.toDouble(),
            ),
            onSkipWarmup: null,
          );
        } else if (isRestingState(stateValue)) {
          final hasExpiredRest =
              restUntil > 0 && restUntil <= nowUnix && nextSet != null;
          if (hasExpiredRest) {
            stateLabel = 'Yapping';
            stateColor = AppTheme.workoutYappingFg;
            timerText = formatRestClock(nowUnix - restUntil);
            timerColor = AppTheme.workoutYappingFg;
            final ProposedSet actionSet = stateSnapshot?.hasDisplaySet() == true
                ? stateSnapshot!.displaySet
                : nextSet;
            displaySet = actionSet;
            actionButton = BigButton(
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
            timerText = formatRestClock(restSeconds);
            final restingSet = stateSnapshot?.hasDisplaySet() == true
                ? stateSnapshot!.displaySet
                : nextSet;
            displaySet = restingSet;
            actionButton = BigButton(
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
        } else if (isReadyState(stateValue) || nextSet != null) {
          final isYapping =
              nextSet != null && lastRestEnd > 0 && lastRestEnd <= nowUnix;
          stateLabel = isYapping ? 'Yapping' : 'Next up';
          stateColor = isYapping
              ? AppTheme.workoutYappingFg
              : colorScheme.tertiary;
          timerText = isYapping ? formatRestClock(nowUnix - lastRestEnd) : null;
          timerColor = isYapping ? AppTheme.workoutYappingFg : null;
          displaySet = stateSnapshot?.hasDisplaySet() == true
              ? stateSnapshot!.displaySet
              : nextSet;
          if (displaySet == null) return const SizedBox.shrink();
          final ProposedSet actionSet = displaySet;
          actionButton = BigButton(
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
              ..sort(compareParticipantsStable);
        final inSession = others.isNotEmpty;
        final visibleOthers = others.length > 4
            ? (List<ParticipantStatus>.from(others)..sort(
                    (a, b) => compareParticipantsByNextWorkout(
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
            ? computeNextToLiftUserId(
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
                    _buildPanelDragTarget(
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
                                  child: DragHandle(
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
                                    MoreParticipantsCard(
                                      hiddenCount: hiddenOtherCount,
                                      onTap: isOnWorkoutPage
                                          ? _showAllParticipantsSheet
                                          : () => context.go('/'),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  for (final p in visibleOthers) ...[
                                    SessionMemberCard(
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
                          HorizontalShaker(
                            active: iAmNextToLift && !_isDraggingPanel,
                            child: inSession
                                ? _buildPanelDragTarget(
                                    child: StatusBox(
                                      sideLabel: 'YOU',
                                      sideBadge: auth.profileEmoji,
                                      // In multiplayer show 'You' header so the rainbow
                                      // "next to lift" label has a home.
                                      header: 'You',
                                      showHeader: true,
                                      headerTrailing: iAmNextToLift
                                          ? const RainbowShimmerText(
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
                                      isComplete: isAllDoneState(stateValue),
                                      sideLabelWidth: 44,
                                    ),
                                  )
                                : StatusBox(
                                    sideLabel: 'YOU',
                                    sideBadge: auth.profileEmoji,
                                    stateLabel: stateLabel,
                                    color: stateColor,
                                    sideColor: profileColorFromHex(
                                      auth.profileColorHex,
                                    ),
                                    timerText: timerText,
                                    timerColor: timerColor,
                                    set: displaySet,
                                    isComplete: isAllDoneState(stateValue),
                                    sideLabelWidth: 44,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TimerHeartBox(
                                elapsedText: elapsedText,
                                heartRateText: heartRateText,
                                heartRateDetected:
                                    latestHeartRate != null &&
                                    latestHeartRate.bpm > 0,
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

