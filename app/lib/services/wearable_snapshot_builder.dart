/// The watch's whole world, built from the phone's state. Both watch apps
/// render this snapshot and nothing else, so what goes in here is the
/// contract: READY / LIFTING / RESTING / YAPPING / ALL_DONE, one status
/// card (the set's weight, reps and plates, and what a tap does), the
/// actions each state offers (Start, then Done), and the set just done for
/// the watch's few seconds of taking reps off it.
library;

import 'dart:math';
import 'package:fixnum/fixnum.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_blocks.dart';
import '../logic/exercises.dart';
import '../logic/plate_calculator.dart';
import '../logic/session_state.dart';
import '../logic/set_labels.dart';
import '../logic/user_profile.dart';
import '../logic/weight_units.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';
import '../screens/workout/live_set_circle.dart';
import '../screens/workout/section_workout.dart';
import '../screens/workout/set_circle.dart';
import '../widgets/participant_ticker.dart';

class WearableSnapshotBuilder {
  static WearWorkoutSnapshot? build({
    required WorkoutProvider workoutProvider,
    required MultiplayerProvider multiplayerProvider,
    required String myUserId,
    required String myProfileEmoji,
  }) {
    final workout = workoutProvider.activeWorkout;
    if (workout == null) return null;
    final isEnded = workout.endTime != Int64.ZERO;
    final hasActive = workoutProvider.hasActiveWorkout;
    if (!hasActive && !isEnded) return null;

    final stateSnapshot = workoutProvider.stateSnapshot;
    final stateValue = isEnded
        ? WorkoutState.WORKOUT_STATE_ALL_DONE.value
        : (stateSnapshot?.state.value ??
              WorkoutState.WORKOUT_STATE_UNSPECIFIED.value);
    final now = workoutProvider.now;
    final nowMs = now.millisecondsSinceEpoch;
    final nowUnix = nowMs ~/ 1000;
    final nextSet = workoutProvider.nextPendingSet;
    final proposedSets = workoutProvider.activeProposedSets;
    final completedSets = workoutProvider.activeCompletedSets;
    final unit = workoutProvider.weightUnit;

    final elapsedSeconds = _elapsedSeconds(workout, nowUnix);

    final snapshot = WearWorkoutSnapshot(
      workoutId: workout.id,
      emittedAt: Int64(nowMs),
      state: isEnded
          ? WorkoutState.WORKOUT_STATE_ALL_DONE
          : (stateSnapshot?.state ?? WorkoutState.WORKOUT_STATE_UNSPECIFIED),
      workoutStartTime: workout.startTime,
      // Set while resting and yapping (the watch's rest-end haptic keys on
      // it), zero while lifting.
      restUntil: stateSnapshot?.restUntil ?? Int64.ZERO,
      liftingStartedAt: stateSnapshot?.liftingStartedAt ?? Int64.ZERO,
      elapsedText: formatElapsedClock(elapsedSeconds < 0 ? 0 : elapsedSeconds),
    );

    final actions = <WearAction>[];

    WearStatusCard card(
      ProposedSet set, {
      String stateLabel = '',
      String timerText = '',
      String cue = '',
    }) {
      final firstTime = _isFirstEver(set, proposedSets, completedSets);
      final barbell =
          workoutProvider.trackerFor(set.exercise)?.equipment ==
          EquipmentKind.EQUIPMENT_KIND_BARBELL;
      final weight = set.targetWeight.toDouble();
      final plates = barbell && !firstTime
          ? calcPlatesPerSide(weight, unit).plates
          : const <double>[];
      String num(double v) => v % 1 == 0 ? v.toInt().toString() : '$v';
      final heaviest = standardPlates(unit).first;
      return WearStatusCard(
        stateLabel: firstTime ? copy.workout.firstTimeStatus : stateLabel,
        timerText: timerText,
        displaySet: set,
        exerciseName: exerciseNames[set.exercise] ?? '?',
        setLine: setLineFor(set, proposedSets),
        setText: setTextFor(set, unit),
        yappingLabel: copy.workout.yapping,
        weightText: firstTime ? '?' : formatWeight(weight, unit),
        unitText: weightUnitSuffix(unit),
        repsText: firstTime ? '?' : '${set.targetReps}',
        cue: firstTime ? copy.workout.watchCueTest : cue,
        firstTime: firstTime,
        plates: [
          for (final p in plates)
            WearPlate(
              label: num(p),
              colorHex: _hex(workoutProvider.plateColor(p).toARGB32()),
              size: (p / heaviest).clamp(0.0, 1.0),
            ),
        ],
        platesText: !barbell || firstTime
            ? ''
            : plates.isEmpty
            ? copy.workout.emptyBar
            : '${plates.map(num).join(' · ')} ${copy.workout.watchEachSide}',
        barText: !barbell || firstTime
            ? ''
            : '${num(standardBarWeight(unit))} ${weightUnitSuffix(unit)}',
      );
    }

    // The one button logs this set: the next pending one, or on an
    // unanswered rung the set "right" would append ("{done}:0").
    final target = isEnded ? null : workoutProvider.doneTargetSet;
    // The watch shows the same state as the phone: lifting counts up from
    // Start, resting counts down to the snapshot's rest end, yapping counts
    // up from it.
    final restEnd = stateSnapshot?.restUntil.toInt() ?? 0;
    final lifting = isLiftingState(stateValue);

    if (target != null && !isAllDoneState(stateValue)) {
      final String stateLabel;
      final String timerText;
      if (lifting) {
        stateLabel = copy.workout.lifting;
        timerText = formatRestClock(
          max(0, nowUnix - stateSnapshot!.liftingStartedAt.toInt()),
        );
      } else if (isRestingState(stateValue)) {
        stateLabel = copy.workout.resting;
        timerText = formatRestClock(max(0, restEnd - nowUnix));
      } else if (isYappingState(stateValue)) {
        stateLabel = copy.workout.yapping;
        timerText = formatRestClock(max(0, nowUnix - restEnd));
      } else {
        stateLabel = copy.workout.ready;
        timerText = '';
      }
      snapshot.youCard = card(
        target,
        stateLabel: stateLabel,
        timerText: timerText,
        cue: lifting
            ? copy.workout.watchCueDone
            : isRestingState(stateValue) || isYappingState(stateValue)
            ? copy.workout.watchCueEarly
            : copy.workout.watchCueLift,
      );
      if (lifting) {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET,
            style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
            label: copy.workout.done,
            setId: target.id,
            reps: target.targetReps,
            actualWeight: target.targetWeight,
          ),
        );
      } else {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_START_SET,
            style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
            label: copy.workout.start,
            setId: target.id,
          ),
        );
      }
    } else if (isAllDoneState(stateValue)) {
      snapshot.completionSummary = _buildCompletionSummary(
        workout: workout,
        nowUnix: nowUnix,
        proposedSets: proposedSets,
        completedSets: completedSets,
        unit: unit,
      );
      if (!isEnded) {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_END_WORKOUT,
            style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
            label: copy.workout.endWorkout,
          ),
        );
      }
    } else {
      return null;
    }

    snapshot.actions.addAll(actions);
    if (target != null) {
      snapshot.circles.addAll(_circles(workoutProvider, target));
    }
    final lastDone = _lastDone(completedSets, proposedSets);
    if (lastDone != null && !isEnded) snapshot.lastDone = lastDone;
    final nextUp = _nextUp(
      status: multiplayerProvider.sessionStatus,
      myUserId: myUserId,
      myProfileEmoji: myProfileEmoji,
      nowUnix: nowUnix,
      stateValue: stateValue,
      restUntil: (stateSnapshot?.restUntil ?? Int64.ZERO).toInt(),
      nextSet: nextSet,
    );
    snapshot.ambientCopy = WearAmbientCopy(
      minLeft: copy.workout.watchMinLeft,
      underAMin: copy.workout.watchUnderAMin,
      minOver: copy.workout.watchMinOver,
      restUntil: copy.workout.watchRestUntil,
    );
    snapshot.nextUpEmoji = nextUp.emoji;
    if (nextUp.me) snapshot.upNextText = copy.workout.upNext;

    return snapshot;
  }

  /// The exercise in hand's sets as the phone's circles draw them, warmups
  /// first; a tap on one is a TapSetIntent.
  static List<WearSetCircle> _circles(
    WorkoutProvider workoutProvider,
    ProposedSet target,
  ) {
    final block = workoutProvider.exerciseBlocks
        .where((b) => b.exercise == target.exercise)
        .firstOrNull;
    if (block == null) return const [];
    final w = SectionWorkout.mine(workoutProvider);
    return [
      for (final set in block.sets)
        if (!set.cancelled)
          WearSetCircle(
            setId: set.id,
            text: _circleText(w, set),
            state: _wearState(LiveSetCircle.setCircleState(w, set)),
            warmup: set.warmup,
          ),
    ];
  }

  static String _circleText(SectionWorkout w, ProposedSet set) {
    final done = w.doneFor(set.id);
    if (done != null) return '${done.actualReps}';
    if (LiveSetCircle.setCircleState(w, set) == SetCircleState.skipped) {
      return '–';
    }
    if (LiveSetCircle.isFirstEver(w, set)) return '?';
    return '${set.targetReps}';
  }

  static WearCircleState _wearState(SetCircleState state) => switch (state) {
    SetCircleState.pending => WearCircleState.WEAR_CIRCLE_STATE_PENDING,
    SetCircleState.next => WearCircleState.WEAR_CIRCLE_STATE_NEXT,
    SetCircleState.lifting => WearCircleState.WEAR_CIRCLE_STATE_LIFTING,
    SetCircleState.full => WearCircleState.WEAR_CIRCLE_STATE_FULL,
    SetCircleState.short => WearCircleState.WEAR_CIRCLE_STATE_SHORT,
    SetCircleState.zero => WearCircleState.WEAR_CIRCLE_STATE_ZERO,
    SetCircleState.skipped => WearCircleState.WEAR_CIRCLE_STATE_SKIPPED,
  };

  /// The opening set of an exercise never done: a calibration set with
  /// none of its exercise's calibration sets lifted yet.
  static bool _isFirstEver(
    ProposedSet set,
    List<ProposedSet> proposedSets,
    List<CompletedSet> completedSets,
  ) {
    if (!set.calibration) return false;
    final done = {for (final c in completedSets) c.proposedSetId};
    return !proposedSets.any(
      (p) => p.exercise == set.exercise && p.calibration && done.contains(p.id),
    );
  }

  /// The set done last, for the watch's fix window.
  static WearDoneSet? _lastDone(
    List<CompletedSet> completedSets,
    List<ProposedSet> proposedSets,
  ) {
    if (completedSets.isEmpty) return null;
    final last = completedSets.reduce((a, b) => b.endedAt > a.endedAt ? b : a);
    final proposed = proposedSets
        .where((p) => p.id == last.proposedSetId)
        .firstOrNull;
    return WearDoneSet(
      completedSetId: last.id,
      reps: last.actualReps,
      targetReps: proposed?.targetReps ?? last.actualReps,
      actualWeight: last.actualWeight,
      endedAt: last.endedAt,
      cue: copy.workout.watchCueFix,
    );
  }

  /// Whose turn it is in a session, as an emoji for the status row, and
  /// whether it is the wearer's. Empty when not in a session or nobody is up.
  static ({String emoji, bool me}) _nextUp({
    required SessionStatus? status,
    required String myUserId,
    required String myProfileEmoji,
    required int nowUnix,
    required int stateValue,
    required int restUntil,
    required ProposedSet? nextSet,
  }) {
    const nobody = (emoji: '', me: false);
    if (status == null || status.participants.isEmpty) return nobody;

    final others = status.participants
        .where((p) => p.user.id.isNotEmpty && p.user.id != myUserId)
        .toList();
    if (others.isEmpty) return nobody;

    // The same client-side logic as the bottom bar decides who's next.
    final nextToLiftUserId = computeNextToLiftUserId(
      myUserId: myUserId,
      others: others,
      nowUnix: nowUnix,
      stateValue: stateValue,
      restUntil: restUntil,
      nextSet: nextSet,
    );
    if (nextToLiftUserId == null) return nobody;
    if (nextToLiftUserId == myUserId) {
      return (emoji: normalizedProfileEmoji(myProfileEmoji), me: true);
    }
    final nextParticipant = others.cast<ParticipantStatus?>().firstWhere(
      (p) => p!.user.id == nextToLiftUserId,
      orElse: () => null,
    );
    return nextParticipant != null
        ? (emoji: participantProfileEmoji(nextParticipant), me: false)
        : nobody;
  }

  static WearCompletionSummary _buildCompletionSummary({
    required Workout workout,
    required int nowUnix,
    required List<ProposedSet> proposedSets,
    required List<CompletedSet> completedSets,
    required WeightUnit unit,
  }) {
    final durationSeconds = _elapsedSeconds(workout, nowUnix);
    final proposedById = {for (final set in proposedSets) set.id: set};

    var completedWorkingSets = 0;
    var totalVolume = 0.0;
    for (final completed in completedSets) {
      final proposed = proposedById[completed.proposedSetId];
      if (proposed == null || !isWorkingSet(proposed)) continue;
      completedWorkingSets++;
      totalVolume += completed.actualWeight * completed.actualReps;
    }

    // The watch prints volume_text as sent; it never formats a weight.
    return WearCompletionSummary(
      durationText: _fmtDurationForSummary(durationSeconds),
      completedWorkingSets: completedWorkingSets,
      totalVolumeLb: totalVolume.round(),
      volumeText: formatWeight(totalVolume, unit, includeUnit: true),
    );
  }
}

/// "#RRGGBB" for an ARGB colour.
String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

int _elapsedSeconds(Workout workout, int nowUnix) {
  final start = workout.startTime.toInt();
  if (start <= 0) return 0;
  final end = workout.endTime.toInt() > 0 ? workout.endTime.toInt() : nowUnix;
  return (end - start).clamp(0, 1 << 30);
}

String _fmtDurationForSummary(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
