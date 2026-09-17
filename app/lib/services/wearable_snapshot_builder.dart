import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'package:fixnum/fixnum.dart';
import '../logic/user_profile.dart';
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

    final elapsedSeconds = _elapsedSeconds(workout, nowUnix);

    final snapshot = WearWorkoutSnapshot(
      workoutId: workout.id,
      emittedAt: Int64(nowMs),
      state: isEnded
          ? WorkoutState.WORKOUT_STATE_ALL_DONE
          : (stateSnapshot?.state ?? WorkoutState.WORKOUT_STATE_UNSPECIFIED),
      workoutStartTime: workout.startTime,
      activeStartedAt: stateSnapshot?.activeStartedAt ?? Int64.ZERO,
      restUntil: stateSnapshot?.restUntil ?? Int64.ZERO,
      lastRestEnd: stateSnapshot?.lastRestEnd ?? Int64.ZERO,
      elapsedText: _fmtElapsed(elapsedSeconds < 0 ? 0 : elapsedSeconds),
    );

    WearStatusCard youCard;
    final actions = <WearAction>[];

    if (_isAllDoneState(stateValue)) {
      youCard = WearStatusCard(
        sideLabel: 'YOU',
        stateLabel: isEnded ? 'Workout complete' : 'All sets complete',
        isComplete: true,
      );
      snapshot.completionSummary = _buildCompletionSummary(
        workout: workout,
        nowUnix: nowUnix,
        proposedSets: proposedSets,
        completedSets: completedSets,
      );
      if (!isEnded) {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_END_WORKOUT,
            style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
            label: 'End Workout',
          ),
        );
      }
    } else if (_isLiftingState(stateValue)) {
      final liftingSnapshot = stateSnapshot;
      if (liftingSnapshot == null || !liftingSnapshot.hasDisplaySet()) {
        return null;
      }
      final proposed = liftingSnapshot.displaySet;
      final activeStartedAt = liftingSnapshot.activeStartedAt.toInt();
      final elapsed = activeStartedAt > 0 ? nowUnix - activeStartedAt : 0;
      final liftLabel = proposed.warmup ? 'Warmup' : 'Lifting';
      youCard = WearStatusCard(
        sideLabel: 'YOU',
        stateLabel: liftLabel,
        timerText: _fmt(elapsed),
        displaySet: proposed,
      );
      _applyExerciseProgress(youCard, proposed, proposedSets);
      final maxReps = proposed.targetReps;
      for (var reps = 0; reps <= maxReps; reps++) {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET,
            style: WearActionStyle.WEAR_ACTION_STYLE_REP_OPTION,
            label: '$reps',
            setId: proposed.id,
            reps: reps,
            actualWeight: proposed.targetWeight,
          ),
        );
      }
    } else if (_isRestingState(stateValue)) {
      final restUntil = stateSnapshot?.restUntil.toInt() ?? 0;
      final hasExpiredRest =
          restUntil > 0 && restUntil <= nowUnix && nextSet != null;
      final actionSet = stateSnapshot?.hasDisplaySet() == true
          ? stateSnapshot!.displaySet
          : nextSet;
      if (actionSet == null) return null;

      if (hasExpiredRest) {
        youCard = WearStatusCard(
          sideLabel: 'YOU',
          stateLabel: 'Yapping',
          timerText: _fmt(nowUnix - restUntil),
          displaySet: actionSet,
        );
        _applyExerciseProgress(youCard, actionSet, proposedSets);
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_START_SET,
            style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
            label: 'Start Set',
            setId: actionSet.id,
          ),
        );
      } else {
        final restSeconds = restUntil > 0
            ? (restUntil - nowUnix).clamp(0, 1 << 30)
            : 0;
        youCard = WearStatusCard(
          sideLabel: 'YOU',
          stateLabel: 'Resting',
          timerText: _fmt(restSeconds),
          displaySet: actionSet,
        );
        _applyExerciseProgress(youCard, actionSet, proposedSets);
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_START_SET,
            style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
            label: 'Start Early',
            setId: actionSet.id,
          ),
        );
      }
      if (workoutProvider.canSkipWarmup(actionSet.id)) {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_SKIP_WARMUP,
            style: WearActionStyle.WEAR_ACTION_STYLE_SECONDARY,
            label: 'Skip Warmup',
            setId: actionSet.id,
          ),
        );
      }
    } else if (_isReadyState(stateValue) || nextSet != null) {
      final displaySet = stateSnapshot?.hasDisplaySet() == true
          ? stateSnapshot!.displaySet
          : nextSet;
      if (displaySet == null) return null;
      final lastRestEnd = stateSnapshot?.lastRestEnd.toInt() ?? 0;
      final isYapping = lastRestEnd > 0 && lastRestEnd <= nowUnix;
      youCard = WearStatusCard(
        sideLabel: 'YOU',
        stateLabel: isYapping ? 'Yapping' : 'Next up',
        timerText: isYapping ? _fmt(nowUnix - lastRestEnd) : '',
        displaySet: displaySet,
      );
      _applyExerciseProgress(youCard, displaySet, proposedSets);
      actions.add(
        WearAction(
          type: WearActionType.WEAR_ACTION_TYPE_START_SET,
          style: WearActionStyle.WEAR_ACTION_STYLE_PRIMARY,
          label: 'Start Set',
          setId: displaySet.id,
        ),
      );
      if (workoutProvider.canSkipWarmup(displaySet.id)) {
        actions.add(
          WearAction(
            type: WearActionType.WEAR_ACTION_TYPE_SKIP_WARMUP,
            style: WearActionStyle.WEAR_ACTION_STYLE_SECONDARY,
            label: 'Skip Warmup',
            setId: displaySet.id,
          ),
        );
      }
    } else {
      return null;
    }

    snapshot.youCard = youCard;
    snapshot.actions.addAll(actions);

    final groupResult = _buildGroupCard(
      status: multiplayerProvider.sessionStatus,
      myUserId: myUserId,
      myProfileEmoji: myProfileEmoji,
      nowUnix: nowUnix,
      stateValue: stateValue,
      restUntil: (stateSnapshot?.restUntil ?? Int64.ZERO).toInt(),
      lastRestEnd: (stateSnapshot?.lastRestEnd ?? Int64.ZERO).toInt(),
      nextSet: nextSet,
    );
    if (groupResult != null) {
      snapshot.groupCard = groupResult.card;
      snapshot.nextUpEmoji = groupResult.emoji;
    }

    return snapshot;
  }

  static void _applyExerciseProgress(
    WearStatusCard card,
    ProposedSet displaySet,
    List<ProposedSet> proposedSets,
  ) {
    final progress = _exerciseProgressForDisplaySet(displaySet, proposedSets);
    if (progress == null) return;
    card
      ..currentGroupSet = progress.$1
      ..totalGroupSets = progress.$2;
  }

  static (int, int)? _exerciseProgressForDisplaySet(
    ProposedSet displaySet,
    List<ProposedSet> proposedSets,
  ) {
    final groupSets =
        proposedSets
            .where(
              (set) =>
                  !set.cancelled &&
                  set.exercise == displaySet.exercise &&
                  set.warmup == displaySet.warmup,
            )
            .toList()
          ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    if (groupSets.isEmpty) return null;
    final currentIndex = groupSets.indexWhere((set) => set.id == displaySet.id);
    if (currentIndex < 0) return null;
    return (currentIndex + 1, groupSets.length);
  }

  static ({WearStatusCard card, String emoji})? _buildGroupCard({
    required SessionStatus? status,
    required String myUserId,
    required String myProfileEmoji,
    required int nowUnix,
    required int stateValue,
    required int restUntil,
    required int lastRestEnd,
    required ProposedSet? nextSet,
  }) {
    if (status == null || status.participants.isEmpty) return null;

    final others = status.participants
        .where((p) => p.user.id.isNotEmpty && p.user.id != myUserId)
        .toList();
    if (others.isEmpty) return null;

    // Use the same client-side logic as the bottom bar to find who's next.
    final nextToLiftUserId = _computeNextToLiftUserId(
      myUserId: myUserId,
      others: others,
      nowUnix: nowUnix,
      stateValue: stateValue,
      restUntil: restUntil,
      lastRestEnd: lastRestEnd,
      nextSet: nextSet,
    );

    // Resolve the next-to-lift emoji — include the current user.
    String nextUpEmoji;
    if (nextToLiftUserId != null && nextToLiftUserId == myUserId) {
      nextUpEmoji = normalizedProfileEmoji(myProfileEmoji);
    } else if (nextToLiftUserId != null) {
      final nextParticipant = others.cast<ParticipantStatus?>().firstWhere(
        (p) => p!.user.id == nextToLiftUserId,
        orElse: () => null,
      );
      nextUpEmoji = nextParticipant != null
          ? participantProfileEmoji(nextParticipant)
          : '';
    } else {
      nextUpEmoji = '';
    }

    // Find the participant to show on the group card — prefer the next-to-lift
    // if it's someone else, otherwise just pick the first other participant.
    ParticipantStatus? target;
    if (nextToLiftUserId != null && nextToLiftUserId != myUserId) {
      target = others.cast<ParticipantStatus?>().firstWhere(
        (p) => p!.user.id == nextToLiftUserId,
        orElse: () => null,
      );
    }
    target ??= others.first;

    final vis = describeParticipantStatus(
      target,
      now: DateTime.fromMillisecondsSinceEpoch(nowUnix * 1000),
    );
    return (
      card: WearStatusCard(
        sideLabel: 'GROUP',
        header: participantDisplayName(target),
        stateLabel: vis.stateLabel,
        timerText: vis.timerText ?? '',
        displaySet: vis.proposedSet,
      ),
      emoji: nextUpEmoji,
    );
  }

  /// Same logic as `_computeNextToLiftUserId` in workout_bottom_bar.dart.
  static String? _computeNextToLiftUserId({
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

  static WearCompletionSummary _buildCompletionSummary({
    required Workout workout,
    required int nowUnix,
    required List<ProposedSet> proposedSets,
    required List<CompletedSet> completedSets,
  }) {
    final durationSeconds = _elapsedSeconds(workout, nowUnix);
    final proposedById = {for (final set in proposedSets) set.id: set};

    var completedWorkingSets = 0;
    var totalVolume = 0.0;
    for (final completed in completedSets) {
      if (completed.endedAt == Int64.ZERO) continue;
      final proposed = proposedById[completed.proposedSetId];
      if (proposed == null || proposed.warmup) continue;
      completedWorkingSets++;
      totalVolume += completed.actualWeight * completed.actualReps;
    }

    return WearCompletionSummary(
      durationText: _fmtDurationForSummary(durationSeconds),
      completedWorkingSets: completedWorkingSets,
      totalVolumeLb: totalVolume.round(),
    );
  }
}

bool _isAllDoneState(int state) =>
    state == WorkoutState.WORKOUT_STATE_ALL_DONE.value;
bool _isLiftingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_LIFTING.value;
bool _isRestingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_RESTING.value;
bool _isReadyState(int state) =>
    state == WorkoutState.WORKOUT_STATE_READY.value;

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
