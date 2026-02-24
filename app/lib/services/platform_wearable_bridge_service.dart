import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../gen/workout/v1/wearable.pb.dart';
import 'wearable_bridge_service.dart';

class PlatformWearableBridgeService implements WearableBridgeService {
  static const MethodChannel _methods = MethodChannel(
    'lift/wear_bridge/methods',
  );
  static const EventChannel _intentEvents = EventChannel(
    'lift/wear_bridge/intents',
  );
  static const EventChannel _sensorEvents = EventChannel(
    'lift/wear_bridge/sensors',
  );

  @override
  Stream<WearIntent> get intentStream => _intentEvents
      .receiveBroadcastStream()
      .map((event) => event as Uint8List)
      .map((bytes) => WearToPhoneEnvelope.fromBuffer(bytes))
      .where((envelope) => envelope.hasIntent())
      .map((envelope) => envelope.intent);

  @override
  Stream<WearSensorBatch> get sensorBatchStream => _sensorEvents
      .receiveBroadcastStream()
      .map((event) => event as Uint8List)
      .map((bytes) => WearToPhoneEnvelope.fromBuffer(bytes))
      .where((envelope) => envelope.hasSensorBatch())
      .map((envelope) => envelope.sensorBatch);

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> publishSnapshot(WearWorkoutSnapshot snapshot) async {
    final envelope = PhoneToWearEnvelope()..snapshot = snapshot;
    await _methods.invokeMethod<void>('publishSnapshot', {
      'payload': envelope.writeToBuffer(),
    });
  }

  @override
  Future<bool> openWatchApp() async {
    final opened = await _methods.invokeMethod<bool>('openWatchApp');
    return opened ?? false;
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
}

WearableBridgeService createWearableBridgeService() {
  if (kIsWeb) return NoopWearableBridgeService();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return PlatformWearableBridgeService();
  }
  return NoopWearableBridgeService();
}
