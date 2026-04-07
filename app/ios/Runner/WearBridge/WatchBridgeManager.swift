import Foundation
import WatchConnectivity
import Flutter

/// Singleton that manages WatchConnectivity on the phone side.
/// Mirrors the Android `WearBridgeManager` — publishes snapshots to watch,
/// receives intents/sensors from watch, tracks UI heartbeat.
class WatchBridgeManager: NSObject, WCSessionDelegate {
    static let shared = WatchBridgeManager()

    private static let watchUiHeartbeatTtlMs: Int64 = 8_000
    private static let phoneToWearEnvelopePath = "/schlift/phone/envelope"
    private static let phoneToWearLaunchPath = "/schlift/phone/launch"
    private static let phoneToWearClockSyncPath = "/schlift/phone/clock_sync"
    private static let wearToPhoneEnvelopePath = "/schlift/wear/envelope"
    private static let wearToPhoneUiHeartbeatPath = "/schlift/wear/ui_heartbeat"
    private static let wearToPhoneClockSyncPath = "/schlift/wear/clock_sync"

    private var intentSink: FlutterEventSink?
    private var sensorSink: FlutterEventSink?
    private var pendingIntentPayloads: [Data] = []
    private var pendingSensorPayloads: [Data] = []
    private var pendingClockSyncs: [String: (Int64) -> Void] = [:]
    private var lastWatchUiHeartbeatAtMs: Int64 = 0
    private let queue = DispatchQueue(label: "com.brensch.schlift.watchbridge", qos: .userInitiated)

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Sink management

    func setIntentSink(_ sink: FlutterEventSink?) {
        queue.async {
            self.intentSink = sink
            if let sink = sink {
                self.flushPendingIntentPayloads(sink)
            }
        }
    }

    func setSensorSink(_ sink: FlutterEventSink?) {
        queue.async {
            self.sensorSink = sink
            if let sink = sink {
                self.flushPendingSensorPayloads(sink)
            }
        }
    }

    // MARK: - Publish snapshot to watch

    func publishSnapshot(_ bytes: FlutterStandardTypedData) {
        guard WCSession.default.activationState == .activated else { return }
        guard WCSession.default.isPaired else { return }

        let message: [String: Any] = [
            "path": WatchBridgeManager.phoneToWearEnvelopePath,
            "data": bytes.data,
        ]

        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            print("SchliftWearBridge: Failed to update watch app context: \(error)")
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("SchliftWearBridge: Failed to send snapshot: \(error)")
            }
        }
    }

    // MARK: - Watch app management

    func isWatchAppAvailable() -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.isPaired && session.isWatchAppInstalled
    }

    func isWatchAppOpenOnWatch() -> Bool {
        let lastSeen = lastWatchUiHeartbeatAtMs
        guard lastSeen > 0 else { return false }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return (now - lastSeen) <= WatchBridgeManager.watchUiHeartbeatTtlMs
    }

    func requestWatchAppOpen(completion: @escaping (Bool) -> Void) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else {
            completion(false)
            return
        }

        // Send a launch message — watch's WCSessionDelegate will receive it
        if WCSession.default.isReachable {
            let message: [String: Any] = ["path": WatchBridgeManager.phoneToWearLaunchPath]
            WCSession.default.sendMessage(message, replyHandler: { _ in
                completion(true)
            }) { error in
                print("SchliftWearBridge: Failed to request watch app open: \(error)")
                completion(false)
            }
        } else {
            WCSession.default.transferUserInfo(["path": WatchBridgeManager.phoneToWearLaunchPath])
            completion(false)
        }
    }

    func requestWatchClockSync(completion: @escaping ([String: Int64]?) -> Void) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isReachable else {
            completion(nil)
            return
        }

        let requestId = UUID().uuidString
        let sentAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let message: [String: Any] = [
            "path": WatchBridgeManager.phoneToWearClockSyncPath,
            "data": Data(requestId.utf8),
        ]

        queue.async {
            self.pendingClockSyncs[requestId] = { watchTimeMs in
                let receivedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
                completion([
                    "watchTimeMs": watchTimeMs,
                    "sentAtMs": sentAtMs,
                    "receivedAtMs": receivedAtMs,
                ])
            }
        }

        WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
            print("SchliftWearBridge: Failed clock sync request: \(error)")
            self?.completeClockSync(requestId: requestId, watchTimeMs: nil, completion: completion)
        }

        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.pendingClockSyncs.removeValue(forKey: requestId) != nil {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("SchliftWearBridge: WCSession activation failed: \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for multi-watch support
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler([:])
    }

    // MARK: - Private

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let path = message["path"] as? String else { return }

        if path == WatchBridgeManager.wearToPhoneUiHeartbeatPath {
            lastWatchUiHeartbeatAtMs = Int64(Date().timeIntervalSince1970 * 1000)
            return
        }

        if path == WatchBridgeManager.wearToPhoneClockSyncPath {
            guard let data = message["data"] as? Data,
                  let payload = String(data: data, encoding: .utf8),
                  let separator = payload.firstIndex(of: ":") else {
                return
            }
            let requestId = String(payload[..<separator])
            guard let watchTimeMs = Int64(String(payload[payload.index(after: separator)...])) else {
                return
            }
            completeClockSync(requestId: requestId, watchTimeMs: watchTimeMs, completion: nil)
            return
        }

        guard path == WatchBridgeManager.wearToPhoneEnvelopePath else { return }
        guard let data = message["data"] as? Data else { return }

        // Parse the envelope to determine if it's an intent or sensor batch.
        // We send the raw bytes to Flutter (same as Android) — Flutter handles deserialization.
        // But we need to peek to route to the correct EventChannel.
        do {
            let envelope = try Workout_V1_WearToPhoneEnvelope(serializedData: data)
            switch envelope.payload {
            case .intent:
                emitIntent(data)
            case .sensorBatch:
                emitSensor(data)
            case .none:
                break
            }
        } catch {
            print("SchliftWearBridge: Failed to parse wear envelope: \(error)")
        }
    }

    private func completeClockSync(
        requestId: String,
        watchTimeMs: Int64?,
        completion fallbackCompletion: (([String: Int64]?) -> Void)?
    ) {
        queue.async {
            let pending = self.pendingClockSyncs.removeValue(forKey: requestId)
            guard let pending = pending else {
                if watchTimeMs == nil, let fallbackCompletion = fallbackCompletion {
                    DispatchQueue.main.async { fallbackCompletion(nil) }
                }
                return
            }
            DispatchQueue.main.async {
                if let watchTimeMs = watchTimeMs {
                    pending(watchTimeMs)
                } else {
                    fallbackCompletion?(nil)
                }
            }
        }
    }

    private func emitIntent(_ bytes: Data) {
        queue.async {
            if let sink = self.intentSink {
                DispatchQueue.main.async { sink(FlutterStandardTypedData(bytes: bytes)) }
            } else {
                self.pendingIntentPayloads.append(bytes)
            }
        }
    }

    private func emitSensor(_ bytes: Data) {
        queue.async {
            if let sink = self.sensorSink {
                DispatchQueue.main.async { sink(FlutterStandardTypedData(bytes: bytes)) }
            } else {
                self.pendingSensorPayloads.append(bytes)
            }
        }
    }

    private func flushPendingIntentPayloads(_ sink: @escaping FlutterEventSink) {
        let payloads = pendingIntentPayloads
        pendingIntentPayloads.removeAll()
        for payload in payloads {
            DispatchQueue.main.async { sink(FlutterStandardTypedData(bytes: payload)) }
        }
    }

    private func flushPendingSensorPayloads(_ sink: @escaping FlutterEventSink) {
        let payloads = pendingSensorPayloads
        pendingSensorPayloads.removeAll()
        for payload in payloads {
            DispatchQueue.main.async { sink(FlutterStandardTypedData(bytes: payload)) }
        }
    }
}
