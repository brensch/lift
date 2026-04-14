import Foundation
import WatchConnectivity
import Flutter

/// Singleton that manages WatchConnectivity on the phone side.
/// Mirrors the Android `WearBridgeManager` — publishes snapshots to watch,
/// receives intents/sensors from watch, tracks UI heartbeat.
class WatchBridgeManager: NSObject, WCSessionDelegate {
    static let shared = WatchBridgeManager()

    private static let watchUiHeartbeatTtlMs: Int64 = 8_000
    private static let phoneToWearSnapshotPath = "/schlift/phone/snapshot"
    private static let phoneToWearLaunchPath = "/schlift/phone/launch"
    private static let phoneToWearClockSyncPath = "/schlift/phone/clock_sync"
    private static let phoneToWearSensorBatchAckPath = "/schlift/phone/sensor_batch_ack"
    private static let wearToPhoneIntentPath = "/schlift/wear/intent"
    private static let wearToPhoneSensorBatchPath = "/schlift/wear/sensor_batch"
    private static let wearToPhoneUiHeartbeatPath = "/schlift/wear/ui_heartbeat"
    private static let wearToPhoneClockSyncPath = "/schlift/wear/clock_sync"
    private static let wearToPhoneSnapshotRequestPath = "/schlift/wear/snapshot_request"

    private var intentSink: FlutterEventSink?
    private var sensorSink: FlutterEventSink?
    private var pendingIntentPayloads: [Data] = []
    private var pendingSensorPayloads: [Data] = []
    private var pendingClockSyncs: [String: (Int64) -> Void] = [:]
    private var lastWatchUiHeartbeatAtMs: Int64 = 0
    private var lastSnapshotBytes: Data?
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

        let data = bytes.data
        queue.async { self.lastSnapshotBytes = data }

        let message: [String: Any] = [
            "path": WatchBridgeManager.phoneToWearSnapshotPath,
            "data": data,
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
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            completion(false)
            return
        }

        let message: [String: Any] = ["path": WatchBridgeManager.phoneToWearLaunchPath]

        // If the watch is reachable, sendMessage will wake/foreground the watch app.
        // Otherwise queue via transferUserInfo so the next time the user taps the
        // app on their wrist, it picks up the launch intent. iOS does not allow
        // cold-launching a suspended watch app from the phone — the user must
        // tap it themselves in that case.
        if session.isReachable {
            session.sendMessage(message, replyHandler: { _ in
                completion(true)
            }) { error in
                print("SchliftWearBridge: sendMessage launch failed, falling back to transferUserInfo: \(error)")
                session.transferUserInfo(message)
                completion(true)
            }
        } else {
            session.transferUserInfo(message)
            completion(true)
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

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncomingMessage(userInfo)
    }

    // MARK: - Private

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let path = message["path"] as? String else { return }

        if path == WatchBridgeManager.wearToPhoneUiHeartbeatPath {
            lastWatchUiHeartbeatAtMs = Int64(Date().timeIntervalSince1970 * 1000)
            return
        }

        if path == WatchBridgeManager.wearToPhoneSnapshotRequestPath {
            queue.async {
                guard let bytes = self.lastSnapshotBytes else { return }
                let replyMessage: [String: Any] = [
                    "path": WatchBridgeManager.phoneToWearSnapshotPath,
                    "data": bytes,
                ]
                let session = WCSession.default
                guard session.activationState == .activated, session.isPaired, session.isReachable else { return }
                session.sendMessage(replyMessage, replyHandler: nil) { error in
                    print("SchliftWearBridge: Failed to send snapshot on request: \(error)")
                }
            }
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

        guard let data = message["data"] as? Data else { return }

        if path == WatchBridgeManager.wearToPhoneIntentPath {
            do {
                _ = try Workout_V1_WearIntent(serializedData: data)
                emitIntent(data)
            } catch {
                print("SchliftWearBridge: Failed to parse wear intent: \(error)")
            }
            return
        }

        if path == WatchBridgeManager.wearToPhoneSensorBatchPath {
            do {
                let batch = try Workout_V1_WearSensorBatch(serializedData: data)
                emitSensor(data)
                sendSensorBatchAck(batch)
            } catch {
                print("SchliftWearBridge: Failed to parse wear sensor batch: \(error)")
            }
        }
    }

    private func sendSensorBatchAck(_ batch: Workout_V1_WearSensorBatch) {
        guard !batch.batchID.isEmpty else { return }
        var ack = Workout_V1_WearSensorBatchAck()
        ack.batchID = batch.batchID
        ack.workoutID = batch.workoutID
        ack.receivedAt = Int64(Date().timeIntervalSince1970 * 1000)
        guard let data = try? ack.serializedData() else { return }

        let message: [String: Any] = [
            "path": WatchBridgeManager.phoneToWearSensorBatchAckPath,
            "data": data,
        ]

        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("SchliftWearBridge: Failed sensor batch ack id=\(batch.batchID): \(error)")
            }
        } else {
            session.transferUserInfo(message)
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
