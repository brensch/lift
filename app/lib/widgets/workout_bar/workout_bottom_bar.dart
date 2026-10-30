/// The banner under every screen while a workout is live: where everyone
/// is. A status bar per partner (at most three in view, the rest a scroll
/// away), yours always at the bottom. It has no buttons of its own: sets are
/// started and logged on their circles. During someone's first workout a
/// line on top says what to do next.
library;

import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/group.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/session_state.dart';
import '../../logic/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';
import '../common/horizontal_shaker.dart';
import '../dialogs/end_workout_dialog.dart';
import '../dialogs/participant_workout_modal.dart';
import '../participant_ticker.dart';
import '../workout_status_box.dart';

/// Partner bars in view before the stack scrolls.
const _maxPartnersInView = 3;
const _gap = 6.0;

/// Your stage, as your status bar shows it.
class _YouState {
  final String label;
  final Color color;
  final String? timerText;
  final ProposedSet? set;

  const _YouState(this.label, this.color, this.timerText, this.set);
}

_YouState _youState(WorkoutProvider wp, ThemeSpec t, int nowUnix) {
  final snapshot = wp.stateSnapshot;
  final state =
      snapshot?.state.value ?? WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
  final restEnd = snapshot?.restUntil.toInt() ?? 0;
  final set = wp.doneTargetSet;
  if (isAllDoneState(state) || set == null) {
    return _YouState(copy.workout.allDone, t.successFg, null, null);
  }
  if (isLiftingState(state)) {
    final startedAt = snapshot!.liftingStartedAt.toInt();
    return _YouState(
      copy.workout.lifting,
      t.workoutLiftingFg,
      formatRestClock(max(0, nowUnix - startedAt)),
      set,
    );
  }
  if (isRestingState(state)) {
    return _YouState(
      copy.workout.resting,
      t.workoutRestingFg,
      formatRestClock(max(0, restEnd - nowUnix)),
      set,
    );
  }
  if (isYappingState(state)) {
    return _YouState(
      copy.workout.yapping,
      t.workoutYappingFg,
      formatRestClock(max(0, nowUnix - restEnd)),
      set,
    );
  }
  return _YouState(copy.workout.ready, t.ready, null, set);
}

/// What to do next, said once: only during the first workout.
String _hint(WorkoutProvider wp) {
  final prompt = wp.effortPrompt;
  if (prompt != null &&
      prompt.calibration &&
      prompt.effort == Effort.EFFORT_UNSPECIFIED) {
    return copy.workout.hints.findingWeight;
  }
  final state =
      wp.stateSnapshot?.state.value ??
      WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
  if (isAllDoneState(state) || wp.doneTargetSet == null) {
    return copy.workout.hints.allDone;
  }
  if (isLiftingState(state)) return copy.workout.hints.lifting;
  if (isRestingState(state)) return copy.workout.hints.resting;
  if (isYappingState(state)) return copy.workout.hints.yapping;
  return copy.workout.hints.ready;
}

class WorkoutBottomBar extends StatefulWidget {
  const WorkoutBottomBar({super.key});

  @override
  State<WorkoutBottomBar> createState() => _WorkoutBottomBarState();
}

class _WorkoutBottomBarState extends State<WorkoutBottomBar>
    with SingleTickerProviderStateMixin {
  /// How far the partners' boxes are out: 1 open, 0 tucked into a row of
  /// their emoji. Dragging the banner moves it under the finger; letting
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
    final range = (_stackHeight - _PartnerRow.height).clamp(1.0, 2000.0);
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
        final state =
            snapshot?.state.value ??
            WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
        final you = _youState(wp, t, nowUnix);

        // Soonest to lift first: the bottom of the stack, next to yours.
        final others =
            mp.participants
                .where((p) => p.user.id.isNotEmpty && p.user.id != auth.userId)
                .toList()
              ..sort(
                (a, b) =>
                    compareParticipantsByNextWorkout(a, b, nowUnix: nowUnix),
              );
        final nextToLift = others.isEmpty
            ? null
            : computeNextToLiftUserId(
                myUserId: auth.userId,
                others: others,
                nowUnix: nowUnix,
                stateValue: state,
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
                timerText: status.timerText,
                set: status.proposedSet,
                plan: p.proposedSets,
              ),
            ),
          );
        }

        final iAmNext = nextToLift != null && nextToLift == auth.userId;
        final allDone = you.set == null;

        return GestureDetector(
          // Anywhere else in the app, the banner is the way back.
          onTap: onWorkoutPage ? null : () => context.go('/'),
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wp.isFirstWorkout) ...[
                      Text(
                        _hint(wp),
                        style: TextStyle(
                          fontSize: t.size.body,
                          fontWeight: t.weight.medium,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (others.isNotEmpty) ...[
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
                      // Open, the boxes; tucked, the emoji row — the one
                      // shrinking as the other grows, under the finger.
                      AnimatedBuilder(
                        animation: _open,
                        builder: (context, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                heightFactor: _open.value,
                                child: Opacity(
                                  opacity: _open.value,
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
                            ),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                heightFactor: 1 - _open.value,
                                child: Opacity(
                                  opacity: 1 - _open.value,
                                  child: _PartnerRow(
                                    partners: others,
                                    upNextId: nextToLift,
                                    onTap: () => _open.animateTo(
                                      1,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _gap),
                    ],
                    HorizontalShaker(
                      active: iAmNext,
                      child: StatusBox(
                        emoji: normalizedProfileEmoji(auth.profileEmoji),
                        profileColor: profileColorFromHex(auth.profileColorHex),
                        stateLabel: you.label,
                        stateColor: you.color,
                        upNext: iAmNext,
                        timerText: you.timerText,
                        set: you.set,
                        plan: wp.activeProposedSets,
                      ),
                    ),
                    if (allDone && wp.activeWorkout?.endTime == Int64.ZERO) ...[
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

/// The partners tucked away: a row of their emoji on their own colours,
/// edged in the colour of the stage each is at; whoever is up next ringed
/// in orange. Tap it to bring their boxes back.
class _PartnerRow extends StatelessWidget {
  final List<ParticipantStatus> partners;
  final String? upNextId;
  final VoidCallback onTap;

  const _PartnerRow({
    required this.partners,
    required this.upNextId,
    required this.onTap,
  });

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: partners.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final p = partners[i];
            final status = describeParticipantStatus(p, tokens: t, now: now);
            final upNext = p.user.id == upNextId;
            return Container(
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: participantProfileColor(p),
                border: Border.all(
                  color: upNext ? t.primary : status.stateColor,
                  width: upNext ? 4 : 3,
                ),
              ),
              child: Text(
                participantProfileEmoji(p),
                style: TextStyle(fontSize: t.size.title, height: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}
