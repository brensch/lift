/// One cue at a rest's end. In the foreground the app plays it, so no OS
/// notification is scheduled; leaving the foreground mid-rest schedules
/// one (it rings if the rest ends out there, even if the app is killed),
/// and coming back cancels it.
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

  setUpAll(tz.initializeTimeZones);

  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            if (call.method == 'zonedSchedule') {
              scheduled.add((call.arguments as Map)['payload']);
            }
            if (call.method == 'cancel') cancels++;
            return null;
          },
        );
    scheduled.clear();
    cancels = 0;
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

  Future<int> rest() async {
    final set = p.proposedSets.firstWhere((s) => !s.warmup);
    await p.startSet(set.id);
    await p.completeSet(set.id, 10, set.targetWeight);
    expect(p.stateSnapshot!.state, WorkoutState.WORKOUT_STATE_RESTING);
    return p.stateSnapshot!.restUntil.toInt();
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
}
