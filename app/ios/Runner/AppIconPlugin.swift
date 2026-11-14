import Flutter
import UIKit

/// The "App icon" setting on iPhone: the "schlift/app_icon" channel Dart
/// calls (`lib/services/app_icon.dart`), the same one Android answers
/// (`appicon/AppIcon.kt`). The icons are the alternate icon sets in the
/// asset catalog (`AppIconLifting`, …, made by
/// `scripts/app_icon_variants.py` and named in the Runner target's
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES); "ready", the orange one,
/// is the primary icon. iOS tells the user itself each time it changes.
public class AppIconPlugin: NSObject, FlutterPlugin {
    /// The setting's names for the alternate icons, and the set each one is.
    private static let alternates = [
        "lifting": "AppIconLifting",
        "resting": "AppIconResting",
        "yapping": "AppIconYapping",
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "schlift/app_icon",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(AppIconPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "get":
            let current = UIApplication.shared.alternateIconName
            let name = AppIconPlugin.alternates.first { $0.value == current }?.key
            result(name ?? "ready")
        case "set":
            let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
            let icon = AppIconPlugin.alternates[name]
            guard name == "ready" || icon != nil, UIApplication.shared.supportsAlternateIcons else {
                result(false)
                return
            }
            UIApplication.shared.setAlternateIconName(icon) { error in
                if let error = error {
                    NSLog("AppIcon: could not change the icon: \(error.localizedDescription)")
                }
                result(error == nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
