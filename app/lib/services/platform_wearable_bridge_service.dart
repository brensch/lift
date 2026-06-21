import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../gen/workout/v1/wearable.pb.dart';
import 'wearable_bridge_service.dart';

class PlatformWearableBridgeService implements WearableBridgeService {
  static const MethodChannel _methods = MethodChannel(
    'schlift/wear_bridge/methods',
  );
  static const EventChannel _intentEvents = EventChannel(
    'schlift/wear_bridge/intents',
  );
  static const EventChannel _sensorEvents = EventChannel(
    'schlift/wear_bridge/sensors',
  );

  @override
  Stream<WearIntent> get intentStream => _intentEvents
      .receiveBroadcastStream()
      .map((event) => event as Uint8List)
      .map(WearIntent.fromBuffer);

  @override
  Stream<WearSensorBatch> get sensorBatchStream => _sensorEvents
      .receiveBroadcastStream()
      .map((event) => event as Uint8List)
      .map(WearSensorBatch.fromBuffer);

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> publishSnapshot(WearWorkoutSnapshot snapshot) async {
    await _methods.invokeMethod<void>('publishSnapshot', {
      'payload': snapshot.writeToBuffer(),
    });
  }

  @override
  Future<bool> openWatchApp() async {
    final opened = await _methods.invokeMethod<bool>('openWatchApp');
    return opened ?? false;
  }

  @override
  Future<void> endWatchWorkout(String workoutId) async {
    // iOS only: the phone can't end the watch's HKWorkoutSession directly, so we send a
    // dedicated command. Android's Wear foreground service already stops reliably via its
    // background WearableListenerService, so skip there (and avoid a MissingPluginException
    // on the shared channel).
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _methods.invokeMethod<void>('endWatchWorkout', {
        'workoutId': workoutId,
      });
    } catch (e) {
      debugPrint('endWatchWorkout failed: $e');
    }
  }

  @override
  Future<bool> isWatchAppAvailable() async {
    final available = await _methods.invokeMethod<bool>('isWatchAppAvailable');
    return available ?? false;
  }

  @override
  Future<bool> isWatchAppOpenOnWatch() async {
    final isOpen = await _methods.invokeMethod<bool>('isWatchAppOpenOnWatch');
    return isOpen ?? false;
  }

  @override
  Future<WatchClockSync?> getWatchClockSync() async {
    final result = await _methods.invokeMapMethod<String, dynamic>(
      'getWatchClockSync',
    );
    if (result == null) return null;
    final watchTimeMs = (result['watchTimeMs'] as num?)?.toInt();
    final sentAtMs = (result['sentAtMs'] as num?)?.toInt();
    final receivedAtMs = (result['receivedAtMs'] as num?)?.toInt();
    if (watchTimeMs == null || sentAtMs == null || receivedAtMs == null) {
      return null;
    }
    return WatchClockSync(
      watchTimeMs: watchTimeMs,
      sentAtMs: sentAtMs,
      receivedAtMs: receivedAtMs,
    );
  }
}

WearableBridgeService createWearableBridgeService() {
  if (kIsWeb) return NoopWearableBridgeService();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return PlatformWearableBridgeService();
  }
  return NoopWearableBridgeService();
}
