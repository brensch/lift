import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'package:fixnum/fixnum.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';

class WearableSnapshotBuilder {
  static WearWorkoutSnapshot? build({
    required WorkoutProvider workoutProvider,
    required MultiplayerProvider multiplayerProvider,
    required String myUserId,
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
      final liftLabel = proposed.warmup
          ? 'Warmup'
          : (proposed.isAmrap ? 'AMRAP' : 'Lifting');
      youCard = WearStatusCard(
        sideLabel: 'YOU',
        stateLabel: liftLabel,
        timerText: _fmt(elapsed),
        displaySet: proposed,
      );
      _applyGroupProgress(youCard, proposed, proposedSets);
      final maxReps = proposed.isAmrap ? 30 : proposed.targetReps;
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
          timerText: '-${_fmt(nowUnix - restUntil)}',
          displaySet: actionSet,
        );
        _applyGroupProgress(youCard, actionSet, proposedSets);
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
        _applyGroupProgress(youCard, actionSet, proposedSets);
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
        timerText: isYapping ? '-${_fmt(nowUnix - lastRestEnd)}' : '',
        displaySet: displaySet,
      );
      _applyGroupProgress(youCard, displaySet, proposedSets);
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

    final groupCard = _buildGroupCard(
      multiplayerProvider.sessionStatus,
      myUserId,
      nowUnix,
    );
    if (groupCard != null) {
      snapshot.groupCard = groupCard;
    }

    return snapshot;
  }

  static void _applyGroupProgress(
    WearStatusCard card,
    ProposedSet displaySet,
    List<ProposedSet> proposedSets,
  ) {
    final progress = _groupProgressForDisplaySet(displaySet, proposedSets);
    if (progress == null) return;
    card
      ..currentGroupSet = progress.$1
      ..totalGroupSets = progress.$2;
  }

  static (int, int)? _groupProgressForDisplaySet(
    ProposedSet displaySet,
    List<ProposedSet> proposedSets,
  ) {
    final groupId = displaySet.exerciseGroupId;
    if (groupId.isEmpty) return null;
    final groupSets = proposedSets
        .where((set) => !set.cancelled && set.exerciseGroupId == groupId)
        .toList()
      ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    if (groupSets.isEmpty) return null;
    final currentIndex = groupSets.indexWhere((set) => set.id == displaySet.id);
    if (currentIndex < 0) return null;
    return (currentIndex + 1, groupSets.length);
  }

  static WearStatusCard? _buildGroupCard(
    SessionStatus? status,
    String myUserId,
    int nowUnix,
  ) {
    if (status == null || status.participants.isEmpty) return null;

    ParticipantStatus? groupActive;
    String groupState = '';
    String groupTimer = '';
    ProposedSet? groupSet;
    String header = '';

    final currentLifterId = status.currentlyLiftingUserId;
    if (currentLifterId.isNotEmpty && currentLifterId != myUserId) {
      final lifting = status.participants.cast<ParticipantStatus?>().firstWhere(
        (p) => p!.user.id == currentLifterId,
        orElse: () => null,
      );
      if (lifting != null) {
        final active = lifting.completedSets.cast<CompletedSet?>().firstWhere(
          (c) => c!.endedAt == Int64.ZERO,
          orElse: () => null,
        );
        final proposed = active == null
            ? null
            : lifting.proposedSets.cast<ProposedSet?>().firstWhere(
                (s) => s!.id == active.proposedSetId,
                orElse: () => null,
              );
        groupActive = lifting;
        groupState = proposed?.warmup == true ? 'Warmup' : 'Lifting';
        groupTimer = active != null
            ? _fmt(nowUnix - active.startedAt.toInt())
            : '';
        groupSet = proposed;
      }
    }

    if (groupActive == null) {
      final nextUpUserId = status.nextUpUserId;
      if (nextUpUserId.isNotEmpty && nextUpUserId != myUserId) {
        final next = status.participants.cast<ParticipantStatus?>().firstWhere(
          (p) => p!.user.id == nextUpUserId,
          orElse: () => null,
        );
        if (next != null) {
          groupActive = next;
          final nextRestUntil = status.nextUpRestUntil.toInt() > 0
              ? status.nextUpRestUntil.toInt()
              : next.restUntil.toInt();
          final remaining = nextRestUntil - nowUnix;
          if (remaining > 0) {
            groupState = 'Resting';
            groupTimer = _fmt(remaining);
          } else if (nextRestUntil > 0) {
            groupState = 'Yapping';
            groupTimer = '+${_fmt(nowUnix - nextRestUntil)}';
          } else {
            groupState = 'Ready';
            groupTimer = 'Ready';
          }
          if (next.hasNextUpSet()) {
            groupSet = next.nextUpSet;
          } else if (status.hasNextUpSet()) {
            groupSet = status.nextUpSet;
          }
        }
      }
    }

    if (groupActive == null) return null;
    header = 'UP NEXT: ${groupActive.user.name}';
    return WearStatusCard(
      sideLabel: 'GROUP',
      header: header,
      stateLabel: groupState,
      timerText: groupTimer,
      displaySet: groupSet,
    );
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
