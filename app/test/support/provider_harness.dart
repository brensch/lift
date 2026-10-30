/// Boots a real WorkoutProvider against the fake service, with the
/// platform channels the provider touches (notifications, prefs) mocked.
/// This is the seam for testing the optimistic appliers and the offline
/// queue without a device.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/settings_provider.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_workout_service.dart';

class ProviderHarness {
  final FakeWorkoutService service;
  final WorkoutProvider provider;
  final SettingsProvider settings;

  ProviderHarness._(this.service, this.provider, this.settings);

  /// Call once per test, after ensureInitialized. Mocks the notification
  /// plugin channel and gives SharedPreferences an empty store. A
  /// [sandbox] provider (the tutorial's kind) touches no platform at all —
  /// use it for paths that would otherwise reach the health plugin.
  static Future<ProviderHarness> boot({bool sandbox = false}) async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async => null,
        );
    final service = FakeWorkoutService();
    final settings = SettingsProvider(GrpcClient(host: '127.0.0.1', port: 1));
    final provider = WorkoutProvider(service, settings, sandbox: sandbox);
    // Let the provider finish restoring its (empty) local cache. Microtasks
    // only — a Timer-based delay would hang under testWidgets' fake clock.
    for (var i = 0; i < 20; i++) {
      await null;
    }
    return ProviderHarness._(service, provider, settings);
  }

  void dispose() {
    provider.dispose();
  }

  /// Seed the provider's home (trackers) so addPrescribedExercises has a
  /// prescription to read.
  Future<void> seedHome(List<ExerciseTracker> trackers) async {
    service.homeResponse = GetHomeResponse(trackers: trackers, onboarded: true);
    await provider.refreshHome();
  }

  /// Start a workout from a canned plan and wait for it to land.
  Future<void> startWorkoutWith(List<ProposedSet> sets) async {
    final workout = Workout()
      ..id = 'w1'
      ..name = 'Test'
      ..startTime = Int64(1000);
    service.startResponse = StartWorkoutResponse(
      id: 'w1',
      workout: workout,
      proposedSets: sets,
    );
    await provider.startWorkout('Test');
  }

  /// Wait past the mutation-flush debounce so queued mutations reach (or
  /// fail against) the fake service.
  Future<void> settleQueue() =>
      Future<void>.delayed(const Duration(milliseconds: 500));
}

/// A resolved tracker. [performed] is true by default: an exercise that
/// has been done before, so an add prescribes its working sets rather
/// than the first-session calibration ramp.
ExerciseTracker tracker(
  Exercise exercise, {
  double weight = 100,
  int sets = 3,
  int reps = 8,
  int rest = 120,
  int restFailure = 180,
  bool performed = true,
}) => ExerciseTracker()
  ..exercise = exercise
  ..workingWeight = weight
  ..sets = sets
  ..targetReps = reps
  ..restSeconds = rest
  ..restSecondsFailure = restFailure
  ..lastPerformedAt = Int64(performed ? 1 : 0);

ProposedSet set_(
  String id,
  Exercise exercise, {
  int order = 0,
  bool warmup = false,
  bool calibration = false,
  double weight = 100,
  int reps = 8,
  int rest = 120,
  int restFailure = 180,
}) => ProposedSet()
  ..id = id
  ..workoutId = 'w1'
  ..workoutOrder = order
  ..exercise = exercise
  ..targetReps = reps
  ..targetWeight = weight
  ..warmup = warmup
  ..calibration = calibration
  ..restAfterSuccess = rest
  ..restAfterFailure = restFailure;

/// One rung of a calibration ramp: five reps at [weight], 90 s rest, as
/// `calibration_set` in core/src/workout/planning.rs builds it.
ProposedSet rung(
  String id,
  Exercise exercise, {
  int order = 0,
  double weight = 45,
}) => set_(
  id,
  exercise,
  order: order,
  calibration: true,
  weight: weight,
  reps: 5,
  rest: 90,
  restFailure: 90,
);
