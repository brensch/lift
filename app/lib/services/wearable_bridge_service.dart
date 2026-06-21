import '../gen/workout/v1/wearable.pb.dart';

/// Transport-agnostic bridge between the phone app and wearable companions.
abstract class WearableBridgeService {
  Stream<WearIntent> get intentStream;
  Stream<WearSensorBatch> get sensorBatchStream;

  Future<void> init();
  Future<void> dispose();

  Future<void> publishSnapshot(WearWorkoutSnapshot snapshot);
  Future<bool> openWatchApp();

  /// Tell the watch to end the given workout's tracking session. The phone cannot end the
  /// watch's HKWorkoutSession directly, so this sends a dedicated guaranteed-delivery
  /// command the watch acts on. No-op where the platform already stops it reliably.
  Future<void> endWatchWorkout(String workoutId);

  Future<bool> isWatchAppAvailable();
  Future<bool> isWatchAppOpenOnWatch();
  Future<WatchClockSync?> getWatchClockSync();
}

class WatchClockSync {
  final int watchTimeMs;
  final int sentAtMs;
  final int receivedAtMs;

  const WatchClockSync({
    required this.watchTimeMs,
    required this.sentAtMs,
    required this.receivedAtMs,
  });

  int get roundTripMs => receivedAtMs - sentAtMs;
  int get estimatedPhoneMidpointMs => sentAtMs + (roundTripMs ~/ 2);
  int get deltaMs => watchTimeMs - estimatedPhoneMidpointMs;
}

class NoopWearableBridgeService implements WearableBridgeService {
  @override
  Stream<WearIntent> get intentStream => const Stream.empty();

  @override
  Stream<WearSensorBatch> get sensorBatchStream => const Stream.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> publishSnapshot(WearWorkoutSnapshot snapshot) async {}

  @override
  Future<void> endWatchWorkout(String workoutId) async {}

  @override
  Future<bool> openWatchApp() async => false;

  @override
  Future<bool> isWatchAppAvailable() async => false;

  @override
  Future<bool> isWatchAppOpenOnWatch() async => false;

  @override
  Future<WatchClockSync?> getWatchClockSync() async => null;
}
