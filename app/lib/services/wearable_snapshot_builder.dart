/// The watch's whole world, built from the phone's state. Both watch apps
/// render this snapshot and nothing else, so what goes in here is the
/// contract: READY / LIFTING / RESTING / YAPPING / ALL_DONE, one status
/// card, and the actions each state offers: Start, then the finish (Done,
/// or for a finding-weight rung how many reps were left, which answers for
/// it in the same tap).
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
import '../logic/session_state.dart';
import '../logic/set_labels.dart';
import '../logic/user_profile.dart';
import '../logic/weight_units.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';
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
    }) => WearStatusCard(
      stateLabel: stateLabel,
      timerText: timerText,
      displaySet: set,
      exerciseName: exerciseNames[set.exercise] ?? '?',
      setLine: setLineFor(set, proposedSets),
      setText: setTextFor(set, unit),
      yappingLabel: copy.workout.yapping,
    );

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
        stateLabel = '';
        timerText = '';
      }
      snapshot.youCard = card(
        target,
        stateLabel: stateLabel,
        timerText: timerText,
      );
      if (lifting && !target.calibration) {
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
      } else if (lifting) {
        // A rung: one Done carrying how many reps were left, the question
        // the phone asks under the rung.
        for (final (effort, label) in [
          (Effort.EFFORT_HARD, copy.workout.repsLeftNone),
          (Effort.EFFORT_RIGHT, copy.workout.repsLeftSome),
          (Effort.EFFORT_EASY, copy.workout.repsLeftLots),
        ]) {
          actions.add(
            WearAction(
              type: WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET,
              style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
              label: label,
              setId: target.id,
              reps: target.targetReps,
              actualWeight: target.targetWeight,
              effort: effort,
            ),
          );
        }
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
    snapshot.nextUpEmoji = _nextUpEmoji(
      status: multiplayerProvider.sessionStatus,
      myUserId: myUserId,
      myProfileEmoji: myProfileEmoji,
      nowUnix: nowUnix,
      stateValue: stateValue,
      restUntil: (stateSnapshot?.restUntil ?? Int64.ZERO).toInt(),
      nextSet: nextSet,
    );

    return snapshot;
  }

  /// Whose turn it is in a session, as an emoji for the status row.
  /// Empty when not in a session or nobody is up.
  static String _nextUpEmoji({
    required SessionStatus? status,
    required String myUserId,
    required String myProfileEmoji,
    required int nowUnix,
    required int stateValue,
    required int restUntil,
    required ProposedSet? nextSet,
  }) {
    if (status == null || status.participants.isEmpty) return '';

    final others = status.participants
        .where((p) => p.user.id.isNotEmpty && p.user.id != myUserId)
        .toList();
    if (others.isEmpty) return '';

    // The same client-side logic as the bottom bar decides who's next.
    final nextToLiftUserId = computeNextToLiftUserId(
      myUserId: myUserId,
      others: others,
      nowUnix: nowUnix,
      stateValue: stateValue,
      restUntil: restUntil,
      nextSet: nextSet,
    );
    if (nextToLiftUserId == null) return '';
    if (nextToLiftUserId == myUserId) {
      return normalizedProfileEmoji(myProfileEmoji);
    }
    final nextParticipant = others.cast<ParticipantStatus?>().firstWhere(
      (p) => p!.user.id == nextToLiftUserId,
      orElse: () => null,
    );
    return nextParticipant != null
        ? participantProfileEmoji(nextParticipant)
        : '';
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
