import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        WatchBridgePlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "WatchBridgePlugin")!)
    }
}
