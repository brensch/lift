import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/group.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/theme/schlift_spec.dart';
import 'package:schlift/widgets/participant_ticker.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(10000 * 1000);
  final nowUnix = 10000;

  ParticipantStatus resting({required int restUntil}) => ParticipantStatus(
    nextUpSet: ProposedSet(id: 's2', targetReps: 5, targetWeight: 135),
    stateSnapshot: WorkoutStateSnapshot(
      state: WorkoutState.WORKOUT_STATE_RESTING,
      restUntil: Int64(restUntil),
    ),
  );

  test('a partner still resting counts down', () {
    final status = describeParticipantStatus(
      resting(restUntil: nowUnix + 30),
      tokens: schliftSpec,
      now: now,
    );
    expect(status.stateLabel, copy.workout.resting);
    expect(status.timerText, '0:30');
  });

  test('a partner who has joined but not started is choosing', () {
    final status = describeParticipantStatus(
      ParticipantStatus(),
      tokens: schliftSpec,
      now: now,
    );
    expect(status.stateLabel, copy.workout.choosing);
    expect(status.isComplete, isFalse);
  });

  test('a partner whose workout has ended is all done', () {
    final status = describeParticipantStatus(
      ParticipantStatus(activeWorkout: Workout(endTime: Int64(nowUnix - 60))),
      tokens: schliftSpec,
      now: now,
    );
    expect(status.stateLabel, copy.workout.allDone);
    expect(status.isComplete, isTrue);
  });

  test("a partner's rest that ran out since their last change is yapping", () {
    final status = describeParticipantStatus(
      resting(restUntil: nowUnix - 75),
      tokens: schliftSpec,
      now: now,
    );
    expect(status.stateLabel, copy.workout.yapping);
    expect(status.timerText, '1:15', reason: 'counting up from the rest end');
  });
}
