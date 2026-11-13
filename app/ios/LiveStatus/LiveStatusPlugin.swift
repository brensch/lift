import ActivityKit
import Flutter

/// The app's side of the live status: the "schlift/live_status" channel
/// Dart calls (`lib/services/live_status.dart`), the same one Android
/// answers (`livestatus/LiveStatus.kt`). `show` starts the Live Activity or
/// updates the one running; `cancel` ends it. Before iOS 16.2 there is no
/// Live Activity and both do nothing.
public class LiveStatusPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "schlift/live_status",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(LiveStatusPlugin(), channel: channel)
    }

    /// The last change asked for: each waits for the one before it, so the
    /// card ends on what was asked for last.
    private var last: Task<Void, Never>?

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(nil)
            return
        }
        handleLive(call, result: result)
    }

    @available(iOS 16.2, *)
    private func handleLive(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "show":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let now = LiveStatusAttributes.Phase(map: args["now"]) else {
                result(FlutterError(code: "invalid_args", message: "Missing now", details: nil))
                return
            }
            let then = LiveStatusAttributes.Phase(map: args["then"])
            let thenAt = (args["thenAtMs"] as? NSNumber).map {
                Date(timeIntervalSince1970: $0.doubleValue / 1000)
            }
            enqueue {
                await LiveStatus.show(now: now, then: then, staleAt: then == nil ? nil : thenAt)
            }
            result(nil)
        case "cancel":
            enqueue { await LiveStatus.end() }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func enqueue(_ change: @escaping () async -> Void) {
        let previous = last
        last = Task {
            await previous?.value
            await change()
        }
    }
}

@available(iOS 16.2, *)
enum LiveStatus {
    /// Show `now`; at `staleAt` (a rest's end) the card moves on to `then`.
    static func show(
        now: LiveStatusAttributes.Phase,
        then: LiveStatusAttributes.Phase?,
        staleAt: Date?
    ) async {
        let content = ActivityContent(
            state: LiveStatusAttributes.ContentState(now: now, then: then),
            staleDate: staleAt
        )
        let running = Activity<LiveStatusAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        if let activity = running.first {
            await activity.update(content)
            return
        }
        // A new one starts only with the app in front and Live Activities
        // allowed; otherwise the next change tries again.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(
                attributes: LiveStatusAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            NSLog("LiveStatus: could not start the Live Activity: \(error.localizedDescription)")
        }
    }

    /// The workout is over: take every card down now.
    static func end() async {
        for activity in Activity<LiveStatusAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@available(iOS 16.2, *)
extension LiveStatusAttributes.Phase {
    /// A phase as the channel sends it; nil when there is none.
    init?(map: Any?) {
        guard let map = map as? [String: Any], let stage = map["stage"] as? String else {
            return nil
        }
        let clockMs = (map["clockMs"] as? NSNumber)?.doubleValue ?? 0
        self.init(
            stage: stage,
            short: map["short"] as? String ?? stage,
            exercise: map["exercise"] as? String ?? "",
            detail: map["detail"] as? String ?? "",
            color: (map["color"] as? NSNumber)?.uint32Value ?? 0xFF00_0000,
            ink: (map["ink"] as? NSNumber)?.uint32Value ?? 0xFFFF_FFFF,
            clock: clockMs > 0 ? Date(timeIntervalSince1970: clockMs / 1000) : nil,
            countDown: map["countDown"] as? Bool ?? false
        )
    }
}
