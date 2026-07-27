// Bug hunt: the live group experience *during* a workout. The app user is mid-
// workout when a peer joins their session and starts logging sets. The app should
// pick up the peer and reflect the shared session on the workout screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multiplayer — a peer joining mid-workout shows on the workout screen',
      (tester) async {
    final s = Scenario(binding, tester, 'multiplayer_workout_progress');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'lifter_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // App user starts their workout SOLO first.
    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.tap(find.text('START WORKOUT').last);
    expect(await s.waitForText('Start Set', seconds: 10), isTrue);
    await s.shot('App user mid-workout, solo');

    // A peer joins the app user's session mid-workout and logs a set.
    final me = await s.api.login(username);
    final invite = await me.inviteToken();
    final bob = await s.api.login('bob_$stamp');
    await bob.joinViaInvite(invite);
    await bob.startWorkout('Squat', Exercise.EXERCISE_SQUAT, 60, 3);
    await bob.completeNextSet(5);

    // The app (mid-workout) should now reflect the 2-person session.
    final sawPeer = await s.waitForText('Multiplayer (2)', seconds: 20);
    await s.shot('Peer joined mid-workout',
        note: sawPeer
            ? 'The workout screen reflects the shared session.'
            : 'WARNING: peer not reflected during the workout.');
    expect(sawPeer, isTrue,
        reason: 'a peer joining mid-workout should show on the workout screen');

    // And the app user's own workout should still be intact (their sets, End Workout).
    expect(s.isVisible('End Workout') || s.isVisible('Start Set'), isTrue,
        reason: 'the app user should still be in their own workout');

    // Backend: both workouts share the session id (the tightened link).
    await me.adoptActiveWorkout();
    final myWorkout = await me.workoutDetail();
    s.note('App user workout session',
        detail: 'session=${myWorkout?.workout.sessionId ?? "?"}', kind: 'api');
    expect(myWorkout?.workout.sessionId.isNotEmpty, isTrue,
        reason: 'the app user\'s workout should be stamped with the session id');

    s.note('Mid-workout peer join verified', kind: 'assert');
    await s.report();
  });
}
