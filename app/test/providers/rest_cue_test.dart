/// One cue at a rest's end. On screen (resumed or inactive) the app plays
/// it, so no OS notification is scheduled; going hidden mid-rest schedules
/// one (it rings if the rest ends out there, even if the app is killed),
/// coming back on screen or cutting the rest short cancels it, and the
/// rest running out does not.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;
  late WorkoutProvider p;
  final scheduled = <Object?>[];
  var cancels = 0;
  var vibrations = 0;

  setUpAll(tz.initializeTimeZones);

  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            // Only the rest's own notification (id 1): the workout's status
            // notification comes and goes on the same channel.
            final args = call.arguments;
            if (args is! Map || args['id'] != 1) return null;
            if (call.method == 'zonedSchedule') {
              scheduled.add(args['payload']);
            }
            if (call.method == 'cancel') cancels++;
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') vibrations++;
          return null;
        });
    scheduled.clear();
    cancels = 0;
    vibrations = 0;
    h = await ProviderHarness.boot();
    await h.seedHistory({Exercise.EXERCISE_LATERAL_RAISE: (20, 10)});
    // The real kind, which schedules notifications; the harness's is a
    // sandbox.
    p = WorkoutProvider(h.service, h.settings)
      ..didChangeAppLifecycleState(AppLifecycleState.resumed);
    await p.startWorkout('Test', exercises: [Exercise.EXERCISE_LATERAL_RAISE]);
  });

  tearDown(() {
    p.dispose();
    h.dispose();
  });

  /// Finish a set and rest; with [endsIn], the set is logged back in time
  /// so the rest runs out that many seconds from now.
  Future<int> rest({int? endsIn}) async {
    final set = p.proposedSets.firstWhere((s) => !s.warmup);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final doneAt = endsIn == null ? null : now - set.restSeconds + endsIn;
    await p.startSet(set.id, startedAt: doneAt == null ? null : doneAt - 30);
    await p.completeSet(set.id, 10, set.targetWeight, completedAt: doneAt);
    expect(p.stateSnapshot!.state, WorkoutState.WORKOUT_STATE_RESTING);
    final restUntil = p.stateSnapshot!.restUntil.toInt();
    if (endsIn != null) expect(restUntil, now + endsIn);
    return restUntil;
  }

  /// Past [restUntil], and a tick or two for the provider to see it.
  Future<void> waitPast(int restUntil) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await Future<void>.delayed(
      Duration(milliseconds: restUntil * 1000 - now + 2200),
    );
    await pumpEventQueue();
  }

  test('a rest in the foreground schedules nothing', () async {
    await rest();
    await pumpEventQueue();
    expect(scheduled, isEmpty);
  });

  test('leaving mid-rest schedules its end; coming back cancels', () async {
    final restUntil = await rest();
    p
      ..didChangeAppLifecycleState(AppLifecycleState.inactive)
      ..didChangeAppLifecycleState(AppLifecycleState.hidden)
      ..didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(scheduled, ['$restUntil'], reason: 'once, on leaving');

    final before = cancels;
    p.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cancels, greaterThan(before));
    expect(scheduled, hasLength(1));
  });

  test('a rest started out of the foreground is scheduled', () async {
    p.didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(scheduled, isEmpty, reason: 'not resting yet');
    final restUntil = await rest();
    await pumpEventQueue();
    expect(scheduled, ['$restUntil']);
  });

  test('a rest that runs out off screen leaves its notification', () async {
    final restUntil = await rest(endsIn: 2);
    p
      ..didChangeAppLifecycleState(AppLifecycleState.inactive)
      ..didChangeAppLifecycleState(AppLifecycleState.hidden)
      ..didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(scheduled, ['$restUntil']);
    final before = cancels;

    await waitPast(restUntil);
    expect(p.stateSnapshot!.state, isNot(WorkoutState.WORKOUT_STATE_RESTING));
    expect(cancels, before, reason: 'the notification is ringing');
    expect(vibrations, 0, reason: 'the notification is the cue');
  });

  test('inactive is on screen: the app gives the cue', () async {
    final restUntil = await rest(endsIn: 2);
    p.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await pumpEventQueue();
    expect(scheduled, isEmpty);

    await waitPast(restUntil);
    expect(p.stateSnapshot!.state, isNot(WorkoutState.WORKOUT_STATE_RESTING));
    expect(vibrations, greaterThan(0));
    expect(scheduled, isEmpty);
  });

  test('the next set started off screen cancels the notification', () async {
    await rest();
    p
      ..didChangeAppLifecycleState(AppLifecycleState.inactive)
      ..didChangeAppLifecycleState(AppLifecycleState.hidden);
    await pumpEventQueue();
    expect(scheduled, hasLength(1));
    final before = cancels;

    final next = p.proposedSets.where((s) => !s.warmup).elementAt(1);
    await p.startSet(next.id);
    await pumpEventQueue();
    expect(p.stateSnapshot!.state, WorkoutState.WORKOUT_STATE_LIFTING);
    expect(cancels, greaterThan(before));
  });
}
