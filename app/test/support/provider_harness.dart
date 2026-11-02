/// Boots a real WorkoutProvider against the real core, on an in-memory
/// account, with the platform channels the provider touches (notifications,
/// prefs) mocked. The core is the host build of app/native
/// (`cargo build -p schlift_native`; `make test-app` does it first).
library;

import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/account.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/settings_provider.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/services/local_core.dart';
import 'package:schlift/services/workout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Load the host build of the core. Tests run from app/.
Future<void> loadCore() {
  final lib = Platform.isMacOS
      ? 'libschlift_native.dylib'
      : Platform.isWindows
      ? 'schlift_native.dll'
      : 'libschlift_native.so';
  return LocalCore.init(
    library: ExternalLibrary.open(
      '${Directory.current.path}/../target/debug/$lib',
    ),
  );
}

class ProviderHarness {
  final LocalCore core;
  final WorkoutServiceWrapper service;
  final WorkoutProvider provider;
  final SettingsProvider settings;

  ProviderHarness._(this.core, this.service, this.provider, this.settings);

  /// Call once per test, after ensureInitialized. A [sandbox] provider (the
  /// tutorial's kind) touches no platform at all.
  static Future<ProviderHarness> boot({bool sandbox = false}) async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async => null,
        );
    await loadCore();
    final core = await LocalCore.memory('test');
    final service = WorkoutServiceWrapper(FixedCore(core));
    final settings = SettingsProvider(service);
    final provider = WorkoutProvider(service, settings, sandbox: sandbox);
    return ProviderHarness._(core, service, provider, settings);
  }

  void dispose() {
    provider.dispose();
    core.close();
  }

  /// A finished session yesterday of each lift in [lifts]: three sets at
  /// its (weight lb, reps), every rep made — so a start plans from that
  /// history: no calibration ramp, no time off.
  Future<void> seedHistory(Map<Exercise, (double, int)> lifts) async {
    final start = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 86400;
    const id = 'seed';
    final proposed = <ProposedSet>[];
    final completed = <CompletedSet>[];
    var t = start;
    for (final MapEntry(key: exercise, value: (weight, reps))
        in lifts.entries) {
      for (var i = 0; i < 3; i++) {
        final setId = '$id-${proposed.length}';
        proposed.add(
          ProposedSet(
            id: setId,
            workoutId: id,
            workoutOrder: proposed.length,
            exercise: exercise,
            targetReps: reps,
            targetWeight: weight,
            restSeconds: 120,
          ),
        );
        t += 160;
        completed.add(
          CompletedSet(
            id: '$setId-done',
            workoutId: id,
            proposedSetId: setId,
            actualReps: reps,
            actualWeight: weight,
            endedAt: Int64(t),
            restUntil: Int64(t + 120),
          ),
        );
      }
    }
    await core.call(
      'ImportHistory',
      ImportHistory(
        workouts: [
          ImportedWorkout(
            workout: Workout(
              id: id,
              name: 'Seed',
              startTime: Int64(start),
              endTime: Int64(t + 60),
            ),
            proposedSets: proposed,
            completedSets: completed,
          ),
        ],
      ),
      ImportHistoryResponse.fromBuffer,
    );
    await provider.loadActiveWorkout('test');
  }

  /// Start a workout of [exercises], as the app does.
  Future<void> start(List<Exercise> exercises) async {
    await provider.startWorkout('Test', exercises: exercises);
  }

  List<ProposedSet> working(Exercise exercise) => provider.proposedSets
      .where((s) => s.exercise == exercise && !s.warmup)
      .toList();
}
