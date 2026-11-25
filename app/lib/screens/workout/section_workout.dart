/// What an exercise section reads about the workout it belongs to — yours,
/// live from the provider, or a session partner's, from their status — so
/// the same section draws both. Only your own workout can be acted on.
library;

import 'package:fixnum/fixnum.dart';

import '../../gen/workout/v1/group.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/session_state.dart';
import '../../providers/workout_provider.dart';

class SectionWorkout {
  final List<CompletedSet> completedSets;

  /// The set being lifted, or empty.
  final String liftingSetId;

  /// The set up next, if any. Empty while a question is open: nothing is
  /// "up next" until it's answered.
  final String? nextSetId;

  /// The Easy/Hard question open on a just-done set, or '': while it's up,
  /// that set shows the inline answer and no next set is highlighted.
  final String questionSetId;

  /// The workout's state on this clock: colours the up-next ring.
  final WorkoutState state;

  /// Undone warmups that are behind you, as the core worked out.
  final Set<String> passedWarmupIds;

  /// Calibration sets of exercises never done before, as the core worked
  /// out: the phone asks for the weight first.
  final Set<String> firstTimeSetIds;

  /// Your own live workout, which taps act on; null for someone else's.
  final WorkoutProvider? actions;

  const SectionWorkout({
    required this.completedSets,
    required this.liftingSetId,
    required this.nextSetId,
    required this.questionSetId,
    required this.state,
    required this.passedWarmupIds,
    required this.firstTimeSetIds,
    required this.actions,
  });

  /// Your workout, live: taps start, finish and correct sets.
  factory SectionWorkout.mine(WorkoutProvider wp) => SectionWorkout(
    completedSets: wp.completedSets,
    liftingSetId: wp.workout?.liftingSetId ?? '',
    // While a question is open, nothing is up next: you answer Easy/Hard
    // before the next set loads, so no circle is highlighted as ready.
    nextSetId: wp.questionSetId.isNotEmpty ? null : wp.doneTargetSet?.id,
    questionSetId: wp.questionSetId,
    state: stateAt(wp.stateSnapshot, wp.now.millisecondsSinceEpoch ~/ 1000),
    passedWarmupIds: {
      for (final s in wp.proposedSets)
        if (wp.isPassedWarmup(s)) s.id,
    },
    firstTimeSetIds: wp.firstTimeSetIds,
    actions: wp.isWorkoutEnded ? null : wp,
  );

  /// A session partner's workout, to look at.
  factory SectionWorkout.of(ParticipantStatus p) {
    final snapshot = p.hasStateSnapshot() ? p.stateSnapshot : null;
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return SectionWorkout(
      completedSets: p.completedSets,
      liftingSetId: p.hasActiveWorkout() ? p.activeWorkout.liftingSetId : '',
      nextSetId: shownSet(snapshot, p.hasNextUpSet() ? p.nextUpSet : null)?.id,
      // A partner's status carries no open question for you to answer.
      questionSetId: '',
      state: stateAt(snapshot, nowUnix),
      passedWarmupIds: p.passedWarmupIds.toSet(),
      firstTimeSetIds: p.firstTimeSetIds.toSet(),
      actions: null,
    );
  }

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

  /// The opening set of an exercise never done before: nothing of its
  /// calibration sets is lifted yet, and it is not being lifted.
  bool isFirstTime(ProposedSet set) => firstTimeSetIds.contains(set.id);
}
