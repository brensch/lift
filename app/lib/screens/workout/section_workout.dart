/// What an exercise section reads about the workout it belongs to — yours,
/// live from the provider, or a session partner's, from their status — so
/// the same section draws both. Only your own workout can be acted on.
library;

import 'package:fixnum/fixnum.dart';

import '../../gen/workout/v1/group.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../providers/workout_provider.dart';

class SectionWorkout {
  final List<CompletedSet> completedSets;
  final List<ProposedSet> proposedSets;

  /// The set being lifted, or empty.
  final String liftingSetId;

  /// The set up next, if any.
  final String? nextSetId;

  /// The workout's state (`WorkoutState` value): colours the up-next ring.
  final int stateValue;

  /// The open "how many were left" on a finding-weight rung, if any.
  final EffortPrompt? effortPrompt;

  /// Undone warmups that are behind you, as the core worked out.
  final Set<String> passedWarmupIds;

  /// Your own live workout, which taps act on; null for someone else's.
  final WorkoutProvider? actions;

  const SectionWorkout({
    required this.completedSets,
    required this.proposedSets,
    required this.liftingSetId,
    required this.nextSetId,
    required this.stateValue,
    required this.effortPrompt,
    required this.passedWarmupIds,
    required this.actions,
  });

  /// Your workout, live: taps start, finish and correct sets.
  factory SectionWorkout.mine(WorkoutProvider wp) => SectionWorkout(
    completedSets: wp.completedSets,
    proposedSets: wp.activeProposedSets,
    liftingSetId: wp.activeWorkout?.liftingSetId ?? '',
    nextSetId: wp.doneTargetSet?.id,
    stateValue:
        wp.stateSnapshot?.state.value ??
        WorkoutState.WORKOUT_STATE_UNSPECIFIED.value,
    effortPrompt: wp.effortPrompt,
    passedWarmupIds: {
      for (final s in wp.activeProposedSets)
        if (wp.isPassedWarmup(s)) s.id,
    },
    actions: wp.isWorkoutEnded ? null : wp,
  );

  /// A session partner's workout, to look at.
  factory SectionWorkout.of(ParticipantStatus p) {
    final snapshot = p.hasStateSnapshot() ? p.stateSnapshot : null;
    // Their snapshot is from their last change: a rest it says is running
    // may have run out since, which on this clock is yapping.
    var state =
        snapshot?.state.value ?? WorkoutState.WORKOUT_STATE_UNSPECIFIED.value;
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (state == WorkoutState.WORKOUT_STATE_RESTING.value &&
        snapshot!.restUntil.toInt() <= nowUnix) {
      state = WorkoutState.WORKOUT_STATE_YAPPING.value;
    }
    return SectionWorkout(
      completedSets: p.completedSets,
      proposedSets: p.proposedSets,
      liftingSetId: p.hasActiveWorkout() ? p.activeWorkout.liftingSetId : '',
      nextSetId: snapshot != null && snapshot.hasDisplaySet()
          ? snapshot.displaySet.id
          : (p.hasNextUpSet() ? p.nextUpSet.id : null),
      stateValue: state,
      effortPrompt: null,
      passedWarmupIds: p.passedWarmupIds.toSet(),
      actions: null,
    );
  }

  bool get live => actions != null;

  CompletedSet? doneFor(String proposedSetId) {
    for (final c in completedSets) {
      if (c.proposedSetId == proposedSetId && c.endedAt != Int64.ZERO) {
        return c;
      }
    }
    return null;
  }

  bool isDone(String proposedSetId) => doneFor(proposedSetId) != null;

  /// An undone warmup that's behind you: skipped, or one of its exercise's
  /// working sets is done.
  bool isPassedWarmup(ProposedSet set) => passedWarmupIds.contains(set.id);
}
