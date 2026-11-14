/// The banner under every screen while a workout is live: where everyone
/// is. A status bar per partner (at most three in view, the rest a scroll
/// away), yours always at the bottom. It has no buttons of its own: sets are
/// started and logged on their circles. A line on top says, when a lift
/// comes up, why its numbers are what they are — and during someone's
/// first workout, what to do next instead.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/group.pb.dart';
import '../../logic/session_state.dart';
import '../../logic/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/workout_provider.dart';
import '../../screens/workout/live_set_circle.dart';
import '../../screens/workout/section_workout.dart';
import '../../screens/workout/workout_pages.dart';
import '../../screens/workout/workout_panels.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';
import '../common/horizontal_shaker.dart';
import '../../logic/motivation.dart';
import '../dialogs/end_workout_dialog.dart';
import '../dialogs/motivation_dialog.dart';
import '../dialogs/participant_workout_modal.dart';
import '../dialogs/weight_adjust_sheet.dart';
import '../participant_ticker.dart';
import '../workout_status_box.dart';
import 'workout_focus.dart';

/// Partner bars in view before the stack scrolls.
const _maxPartnersInView = 3;
const _gap = 6.0;

class WorkoutBottomBar extends StatefulWidget {
  const WorkoutBottomBar({super.key});

  @override
  State<WorkoutBottomBar> createState() => _WorkoutBottomBarState();
}

class _WorkoutBottomBarState extends State<WorkoutBottomBar>
    with SingleTickerProviderStateMixin {
  /// How far the partners' boxes are out: 1 open, 0 tucked away, a box
  /// with how many are training in their place. Dragging the banner moves it under the finger; letting
  /// go settles it by the fling, or by whichever end is nearer.
  late final AnimationController _open;

  /// The open stack's height, measured, so the drag maps pixel for pixel.
  final _stackKey = GlobalKey();
  double _stackHeight = 200;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _measure() {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.height > 0) {
      _stackHeight = box.size.height;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _measure();
    final range = _stackHeight.clamp(1.0, 2000.0);
    _open.value -= (d.primaryDelta ?? 0) / range;
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v.abs() > 300 ? v < 0 : _open.value >= 0.5;
    _open.animateTo(open ? 1 : 0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    if (!wp.hasActiveWorkout) return const SizedBox.shrink();

    // Outside a routed subtree (the tutorial's sandbox is a plain pushed
    // page) the banner is on the workout page by construction.
    String currentUri;
    try {
      currentUri = GoRouterState.of(context).uri.toString();
    } on GoError {
      currentUri = '/';
    }
    final onWorkoutPage = currentUri == '/';

    return ValueListenableBuilder<DateTime>(
      valueListenable: wp.clock,
      builder: (context, now, _) {
        final t = context.tokens;
        final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
        final snapshot = wp.stateSnapshot;
        final you = workoutVisualStatus(
          snapshot: snapshot,
          set: wp.doneTargetSet,
          completedSets: wp.completedSets,
          nowUnix: nowUnix,
          tokens: t,
        );
        // The workout's clock and your heart rate, each a box that opens
        // its page: the clock the log of sets done, the heart the chart.
        final workout = wp.workout;
        final ended = workout != null && workout.endTime != Int64.ZERO;
        // The exercise of the set in hand: the pencil by its weight edits it.
        final editBlock = wp.exerciseBlocks
            .where((b) => b.exercise == you.proposedSet?.exercise)
            .firstOrNull;
        final elapsed = workout == null || workout.startTime == Int64.ZERO
            ? 0
            : (ended ? workout.endTime.toInt() : nowUnix) -
                  workout.startTime.toInt();
        final beat = wp.wearHeartRateSamples.isNotEmpty
            ? wp.wearHeartRateSamples.last
            : null;
        final figure = t.mono(
          TextStyle(
            fontSize: t.size.bodyLg,
            fontWeight: t.weight.bold,
            color: t.text,
            height: 1,
          ),
        );

        // Soonest to lift first: the bottom of the stack, next to yours.
        final others =
            mp.participants
                .where((p) => p.user.id.isNotEmpty && p.user.id != auth.userId)
                .toList()
              ..sort(
                (a, b) =>
                    compareParticipantsByNextWorkout(a, b, nowUnix: nowUnix),
              );
        final nextToLift = computeNextToLiftUserId(
          myUserId: auth.userId,
          participants: mp.participants,
          nowUnix: nowUnix,
          state: stateAt(snapshot, nowUnix),
          restUntil: snapshot?.restUntil.toInt() ?? 0,
          nextSet: wp.nextPendingSet,
        );

        Widget partnerCard(ParticipantStatus p, {Key? key}) {
          final status = describeParticipantStatus(p, tokens: t, now: now);
          final upNext = nextToLift == p.user.id;
          return GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onWorkoutPage
                ? () => showParticipantWorkoutModal(context, p)
                : () => context.go('/'),
            child: HorizontalShaker(
              active: upNext,
              child: StatusBox(
                emoji: participantProfileEmoji(p),
                profileColor: participantProfileColor(p),
                stateLabel: status.stateLabel,
                stateColor: status.stateColor,
                upNext: upNext,
                compact: true,
                timerText: status.timerText,
                restLeft: status.restLeft,
                set: status.proposedSet,
                plan: p.proposedSets,
              ),
            ),
          );
        }

        final iAmNext = nextToLift != null && nextToLift == auth.userId;
        final allDone = you.proposedSet == null;

        return GestureDetector(
          // The banner is the way back to where you're up to: the workout
          // page, scrolled to the exercise in hand.
          onTap: () {
            if (!onWorkoutPage) context.go('/');
            requestWorkoutFocus();
          },
          onVerticalDragUpdate: others.isEmpty ? null : _onDragUpdate,
          onVerticalDragEnd: others.isEmpty ? null : _onDragEnd,
          child: Container(
            decoration: BoxDecoration(
              color: t.surfaceHigh,
              border: Border(
                top: BorderSide(color: t.outline.withValues(alpha: 0.5)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (others.isNotEmpty)
                      // The handle: the banner drags down to tuck the
                      // partners away, up to bring them back.
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          color: t.outline,
                        ),
                      ),
                    // Each only as wide as what it shows: to the right, the
                    // workout's; to the left, with the partners tucked away,
                    // how many are training (a tap brings them back).
                    Row(
                      children: [
                        if (others.isNotEmpty)
                          AnimatedBuilder(
                            animation: _open,
                            builder: (context, child) => IgnorePointer(
                              ignoring: _open.value > 0.5,
                              child: Opacity(
                                opacity: 1 - _open.value,
                                child: child,
                              ),
                            ),
                            child: OpenBox(
                              tooltip: copy.menu.multiplayer,
                              onTap: () =>
                                  _open.animateTo(1, curve: Curves.easeOut),
                              children: [
                                Icon(
                                  AppIcons.multiplayer,
                                  size: t.size.bodyLg,
                                  color: t.text,
                                ),
                                const SizedBox(width: 6),
                                Text('${others.length + 1}', style: figure),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (workout != null) ...[
                          OpenBox(
                            tooltip: copy.motivation.title,
                            onTap: () => showMotivationDialog(
                              context,
                              motivationFor(workout),
                            ),
                            children: [
                              Text(
                                copy.motivation.button,
                                style: TextStyle(
                                  fontSize: t.size.bodyLg,
                                  fontWeight: t.weight.bold,
                                  color: t.text,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: _gap),
                        ],
                        OpenBox(
                          tooltip: copy.workoutPage.tabHeart,
                          onTap: () => openWorkoutHeart(context),
                          children: [
                            Icon(
                              AppIcons.heart,
                              size: t.size.bodyLg,
                              color: t.heart,
                            ),
                            if (!ended && beat != null && beat.bpm > 0) ...[
                              const SizedBox(width: 6),
                              Text('${beat.bpm.round()}', style: figure),
                            ],
                          ],
                        ),
                        const SizedBox(width: _gap),
                        OpenBox(
                          tooltip: copy.workoutPage.tabLog,
                          onTap: () => openWorkoutLog(context),
                          children: [
                            Icon(
                              AppIcons.clock,
                              size: t.size.bodyLg,
                              color: t.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatElapsedClock(elapsed < 0 ? 0 : elapsed),
                              style: figure,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: _gap),
                    if (others.isNotEmpty) ...[
                      // The partners' boxes, drawn away under the finger;
                      // tucked, nothing of them is left.
                      AnimatedBuilder(
                        animation: _open,
                        builder: (context, child) => ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: _open.value,
                            child: Opacity(opacity: _open.value, child: child),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: _gap),
                          child: KeyedSubtree(
                            key: _stackKey,
                            child: _PartnerStack(
                              count: others.length,
                              builder: (i, key) =>
                                  partnerCard(others[i], key: key),
                            ),
                          ),
                        ),
                      ),
                    ],
                    HorizontalShaker(
                      active: iAmNext,
                      child: StatusBox(
                        emoji: normalizedProfileEmoji(auth.profileEmoji),
                        profileColor: profileColorFromHex(auth.profileColorHex),
                        stateLabel: you.stateLabel,
                        stateColor: you.stateColor,
                        upNext: iAmNext,
                        timerText: you.timerText,
                        restLeft: you.restLeft,
                        set: you.proposedSet,
                        plan: wp.proposedSets,
                        circle: you.proposedSet == null
                            ? null
                            : LiveSetCircle(
                                workout: SectionWorkout.mine(wp),
                                set: you.proposedSet!,
                              ),
                        onEdit: ended || editBlock == null
                            ? null
                            : () => editExercise(context, wp, editBlock),
                        firstTime:
                            you.proposedSet != null &&
                            wp.firstTimeSetIds.contains(you.proposedSet!.id),
                      ),
                    ),
                    if (allDone && wp.workout?.endTime == Int64.ZERO) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: () => endWorkout(context),
                          child: Text(
                            copy.workout.endWorkout,
                            style: TextStyle(
                              fontSize: t.size.bodyLg,
                              fontWeight: t.weight.heavy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Partner cards above yours: at most [_maxPartnersInView] in view, the rest
/// a scroll away. Built from the bottom, so the partner soonest to lift sits
/// against your card. The view is sized from a measured card.
class _PartnerStack extends StatefulWidget {
  final int count;
  final Widget Function(int index, Key? key) builder;

  const _PartnerStack({required this.count, required this.builder});

  @override
  State<_PartnerStack> createState() => _PartnerStackState();
}

class _PartnerStackState extends State<_PartnerStack> {
  final _firstCard = GlobalKey();
  double? _cardHeight;

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _firstCard.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.hasSize == true ? box!.size.height : null;
      if (height != null && height > 0 && height != _cardHeight) {
        setState(() => _cardHeight = height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final list = ListView.separated(
      reverse: true,
      shrinkWrap: true,
      // Only a stack taller than the view scrolls; otherwise a drag on a
      // box is the banner's, to tuck the partners away.
      physics: widget.count > _maxPartnersInView
          ? null
          : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.count,
      separatorBuilder: (_, __) => const SizedBox(height: _gap),
      itemBuilder: (_, i) => widget.builder(i, i == 0 ? _firstCard : null),
    );
    final card = _cardHeight;
    if (widget.count <= _maxPartnersInView || card == null) return list;
    return SizedBox(
      height: _maxPartnersInView * card + (_maxPartnersInView - 1) * _gap,
      child: list,
    );
  }
}
