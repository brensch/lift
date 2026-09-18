import Flutter
import Foundation
import HealthKit
import WatchConnectivity

extension WatchBridgeManager {
    func handleIncomingMessage(_ message: [String: Any]) {
        guard let path = message["path"] as? String else { return }

        if path == WatchBridgeManager.wearToPhoneUiHeartbeatPath {
            lastWatchUiHeartbeatAtMs = Int64(Date().timeIntervalSince1970 * 1000)
            return
        }

        if path == WatchBridgeManager.wearToPhoneSnapshotRequestPath {
            sendSnapshotOnRequest()
            return
        }

        if path == WatchBridgeManager.wearToPhoneClockSyncPath {
            handleClockSyncReply(message)
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

    private func sendSnapshotOnRequest() {
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
    }

    private func handleClockSyncReply(_ message: [String: Any]) {
        guard let data = message["data"] as? Data,
              let payload = String(data: data, encoding: .utf8),
              let separator = payload.firstIndex(of: ":")
        else {
            return
        }
        let requestId = String(payload[..<separator])
        guard let watchTimeMs = Int64(String(payload[payload.index(after: separator)...])) else {
            return
        }
        completeClockSync(requestId: requestId, watchTimeMs: watchTimeMs, completion: nil)
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

    func completeClockSync(
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
}
