import '../gen/workout/v1/wearable.pb.dart';

/// Transport-agnostic bridge between the phone app and wearable companions.
abstract class WearableBridgeService {
  Stream<WearIntent> get intentStream;
  Stream<WearSensorBatch> get sensorBatchStream;

  Future<void> init();
  Future<void> dispose();

  Future<void> publishSnapshot(WearWorkoutSnapshot snapshot);
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
}
