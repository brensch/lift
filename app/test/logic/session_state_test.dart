import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/group.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/session_state.dart';

/// Who lifts next in a group: the phone's bar and the watch both mark them.
void main() {
  const now = 10000;
  const resting = WorkoutState.WORKOUT_STATE_RESTING;
  const lifting = WorkoutState.WORKOUT_STATE_LIFTING;
  final mySet = ProposedSet(id: 'mine');

  ParticipantStatus partner(
    String id, {
    WorkoutState state = resting,
    int restUntil = 0,
    bool hasNext = true,
    bool ended = false,
    String name = '',
  }) => ParticipantStatus(
    user: User(id: id, name: name),
    activeWorkout: Workout(endTime: Int64(ended ? now - 60 : 0)),
    nextUpSet: hasNext ? ProposedSet(id: '$id-next') : null,
    stateSnapshot: WorkoutStateSnapshot(
      state: state,
      restUntil: Int64(restUntil),
    ),
  );

  String? next(
    List<ParticipantStatus> participants, {
    WorkoutState state = resting,
    int restUntil = now + 60,
    ProposedSet? nextSet,
  }) => computeNextToLiftUserId(
    myUserId: 'me',
    participants: participants,
    nowUnix: now,
    state: state,
    restUntil: restUntil,
    nextSet: nextSet ?? mySet,
  );

  group('next to lift', () {
    test('nobody else in the session: no one', () {
      expect(next([]), isNull);
      expect(next([partner('me')]), isNull, reason: "I'm not an other");
    });

    test('the rest that ends first', () {
      expect(next([partner('b', restUntil: now + 30)]), 'b');
      expect(next([partner('b', restUntil: now + 90)]), 'me');
    });

    test('a partner lifting, done or ended is not waiting', () {
      expect(next([partner('b', state: lifting)]), 'me');
      expect(next([partner('b', hasNext: false, restUntil: now + 1)]), 'me');
      expect(next([partner('b', ended: true, restUntil: now + 1)]), 'me');
      expect(
        next([partner('b', state: lifting)], state: lifting),
        isNull,
        reason: 'nobody waiting',
      );
    });

    test('a rest that ran out (yapping) counts from when it ended', () {
      expect(
        next([
          partner('b', restUntil: now + 10),
          partner('c', restUntil: now - 30),
        ]),
        'c',
      );
    });

    test('no rest running is due now', () {
      expect(
        next([
          partner('b', state: WorkoutState.WORKOUT_STATE_READY),
        ], restUntil: now - 5),
        'me',
        reason: 'my rest ended 5 s ago, before now',
      );
    });

    test('a tie goes to the smaller user id, me included', () {
      expect(
        next([
          partner('d', restUntil: now + 30),
          partner('c', restUntil: now + 30),
        ]),
        'c',
      );
      expect(next([partner('a', restUntil: now + 60)]), 'a');
      expect(next([partner('z', restUntil: now + 60)]), 'me');
    });
  });

  test('partners sort by when they are due, then by name, then id', () {
    final order = [
      partner('x', name: 'zed', state: lifting),
      partner('y', name: 'Amy', state: lifting),
      partner('w', name: 'amy', state: lifting),
      partner('v', name: 'late', restUntil: now + 60),
      partner('u', name: 'soon', restUntil: now + 10),
    ]..sort((a, b) => compareParticipantsByNextWorkout(a, b, nowUnix: now));
    expect(order.map((p) => p.user.id), ['u', 'v', 'w', 'y', 'x']);
  });

  test('a display name falls back to the id, then Unknown', () {
    expect(participantDisplayName(partner('id', name: ' Bo ')), 'Bo');
    expect(participantDisplayName(partner('id')), 'id');
    expect(participantDisplayName(ParticipantStatus()), 'Unknown');
  });

  test('clocks', () {
    expect(formatElapsedClock(3725), '1:02:05');
    expect(formatElapsedClock(65), '1:05');
    expect(formatDurationShort(3900), '1h 5m');
    expect(formatDurationShort(2700), '45m');
    expect(formatRestClock(-75), '1:15');
  });

  test('the rest-end cue is for a rest that ended just now', () {
    final rest = WorkoutStateSnapshot(state: resting, restUntil: Int64(now));
    expect(restEndedJustNow(rest, now), isTrue);
    expect(restEndedJustNow(rest, now + 1), isTrue);
    expect(restEndedJustNow(rest, now + 2), isTrue);
    expect(
      restEndedJustNow(rest, now + 120),
      isFalse,
      reason: 'back two minutes later: the notification rang at the end',
    );
  });
}
