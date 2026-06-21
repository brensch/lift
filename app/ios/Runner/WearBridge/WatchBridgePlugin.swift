import Flutter
import UIKit

/// Flutter plugin that exposes the same platform channel API as Android's WearBridgeManager.
/// Channels:
///   - MethodChannel("schlift/wear_bridge/methods")
///   - EventChannel("schlift/wear_bridge/intents")
///   - EventChannel("schlift/wear_bridge/sensors")
public class WatchBridgePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()

        // Initialize the singleton (activates WCSession)
        _ = WatchBridgeManager.shared

        // Method channel
        let methodChannel = FlutterMethodChannel(
            name: "schlift/wear_bridge/methods",
            binaryMessenger: messenger
        )
        let instance = WatchBridgePlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Intent event channel
        let intentChannel = FlutterEventChannel(
            name: "schlift/wear_bridge/intents",
            binaryMessenger: messenger
        )
        intentChannel.setStreamHandler(IntentStreamHandler())

        // Sensor event channel
        let sensorChannel = FlutterEventChannel(
            name: "schlift/wear_bridge/sensors",
            binaryMessenger: messenger
        )
        sensorChannel.setStreamHandler(SensorStreamHandler())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "publishSnapshot":
            guard let args = call.arguments as? [String: Any],
                  let payload = args["payload"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "invalid_args", message: "Missing payload", details: nil))
                return
            }
            WatchBridgeManager.shared.publishSnapshot(payload)
            result(nil)

        case "openWatchApp":
            WatchBridgeManager.shared.requestWatchAppOpen { success in
                result(success)
            }

        case "isWatchAppAvailable":
            result(WatchBridgeManager.shared.isWatchAppAvailable())

        case "isWatchAppOpenOnWatch":
            result(WatchBridgeManager.shared.isWatchAppOpenOnWatch())

        case "getWatchClockSync":
            WatchBridgeManager.shared.requestWatchClockSync { sync in
                result(sync)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Stream handlers

private class IntentStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        WatchBridgeManager.shared.setIntentSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        WatchBridgeManager.shared.setIntentSink(nil)
        return nil
    }
}

private class SensorStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        WatchBridgeManager.shared.setSensorSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        WatchBridgeManager.shared.setSensorSink(nil)
        return nil
    }
}
