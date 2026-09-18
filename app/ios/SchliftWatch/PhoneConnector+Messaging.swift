import Foundation
import WatchConnectivity
import WatchKit

extension PhoneConnector {
    func sendIntent(action: Workout_V1_WearAction) {
        // Explicit end from the watch: tear the session down immediately rather than waiting
        // for the phone to echo back an "ended" snapshot. We still send the intent below so
        // the phone ends the workout too.
        if action.type == .endWorkout {
            endLocalSession()
        }

        guard !isActionPending else { return }
        guard let workoutId = snapshot?.workoutID, !workoutId.isEmpty else { return }

        var intent = Workout_V1_WearIntent()
        intent.intentID = UUID().uuidString
        intent.sentAt = Int64(Date().timeIntervalSince1970)

        switch action.type {
        case .startSet:
            var startSet = Workout_V1_StartSetIntent()
            startSet.workoutID = workoutId
            startSet.setID = action.setID
            intent.intent = .startSet(startSet)

        case .completeSet:
            var completeSet = Workout_V1_CompleteSetIntent()
            completeSet.workoutID = workoutId
            completeSet.setID = action.setID
            completeSet.reps = action.reps
            completeSet.actualWeight = action.actualWeight
            completeSet.completedAt = Int64(Date().timeIntervalSince1970)
            intent.intent = .completeSet(completeSet)

        case .skipWarmup:
            var skipWarmup = Workout_V1_SkipWarmupIntent()
            skipWarmup.workoutID = workoutId
            skipWarmup.setID = action.setID
            intent.intent = .skipWarmup(skipWarmup)

        case .endWorkout:
            var endWorkout = Workout_V1_EndWorkoutIntent()
            endWorkout.workoutID = workoutId
            intent.intent = .endWorkout(endWorkout)

        default:
            return
        }

        guard let data = try? intent.serializedData() else { return }
        // Do NOT gate on isReachable — sendToPhone falls back to guaranteed transferUserInfo
        // delivery when the phone app isn't reachable, so the button press is never silently
        // dropped (the root cause of "I press it and nothing happens" + the watch/phone wedge).
        beginPendingAction()
        sendToPhone(path: WatchPaths.wearToPhoneIntent, data: data)
    }

    func handleIncomingMessage(_ message: [String: Any]) {
        guard let path = message["path"] as? String else { return }

        if path == WatchPaths.phoneToWearEndWorkout {
            // Dedicated, unconditional end command from the phone, delivered via
            // transferUserInfo (guaranteed) — the reliable way to stop the watch's HK session
            // when the user ends on the phone, bypassing the snapshot pipeline entirely.
            let id = (message["data"] as? Data).flatMap { String(data: $0, encoding: .utf8) }
            DispatchQueue.main.async {
                self.endLocalSession(workoutID: id)
            }
            return
        }

        if path == WatchPaths.phoneToWearLaunch {
            DispatchQueue.main.async {
                self.setUIVisible(true)
                self.sendHeartbeat()
            }
            return
        }

        if path == WatchPaths.phoneToWearClockSync {
            guard let data = message["data"] as? Data,
                  let requestId = String(data: data, encoding: .utf8)
            else {
                return
            }
            let payload = "\(requestId):\(Int64(Date().timeIntervalSince1970 * 1000))"
            sendToPhone(path: WatchPaths.wearToPhoneClockSync, data: Data(payload.utf8))
            return
        }

        if path == WatchPaths.phoneToWearSensorBatchAck {
            guard let data = message["data"] as? Data,
                  let ack = try? Workout_V1_WearSensorBatchAck(serializedBytes: data)
            else {
                return
            }
            sensorBatchOutbox.acknowledge(ack)
            return
        }

        if path == WatchPaths.phoneToWearSnapshot {
            guard let data = message["data"] as? Data else { return }
            guard let snapshot = try? Workout_V1_WearWorkoutSnapshot(serializedBytes: data) else { return }
            DispatchQueue.main.async {
                self.handleSnapshot(snapshot)
            }
        }
    }

    @discardableResult
    func enqueueSensorBatch(_ batch: Workout_V1_WearSensorBatch) -> Bool {
        let enqueued = sensorBatchOutbox.enqueue(batch)
        guard enqueued else { return false }
        flushPendingSensorBatches()
        return true
    }

    func flushPendingSensorBatches() {
        let batches = sensorBatchOutbox.pendingBatches()
        guard !batches.isEmpty else { return }
        for batch in batches {
            guard let data = try? batch.serializedData() else {
                sensorBatchOutbox.remove(batchID: batch.batchID)
                continue
            }
            let sent = sendToPhone(
                path: WatchPaths.wearToPhoneSensorBatch,
                data: data,
                preferBackgroundDelivery: true
            )
            if !sent {
                return
            }
        }
    }

    @discardableResult
    private func sendToPhone(
        path: String,
        data: Data,
        preferBackgroundDelivery: Bool = false
    ) -> Bool {
        let session = WCSession.default
        let message: [String: Any] = ["path": path, "data": data]

        guard session.activationState == .activated else {
            print("SchliftWatch: WCSession not activated for path \(path)")
            return false
        }

        // When the phone app isn't reachable (backgrounded), sendMessage cannot deliver.
        // Fall back to transferUserInfo — WCSession's GUARANTEED FIFO delivery, which reaches
        // the phone app even when it's not running (the equivalent of Android's
        // MessageClient → WearableListenerService). This is what stops button presses from
        // being silently dropped and the two sides from wedging out of sync. Intents are
        // idempotent (deduped by intentID on the phone), so guaranteed-but-delayed is safe.
        if preferBackgroundDelivery || !session.isReachable {
            session.transferUserInfo(message)
            return true
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("SchliftWatch: sendMessage failed, falling back to transferUserInfo: \(error)")
            // The live send failed — re-queue via guaranteed delivery so the action still
            // reaches the phone. Don't clear the pending action here; the resulting snapshot
            // (or the 2s safety timeout) re-enables the button.
            session.transferUserInfo(message)
        }
        return true
    }

    /// The phone always mirrors the latest snapshot into updateApplicationContext, which the
    /// system delivers to the watch without requiring reachability and caches in
    /// receivedApplicationContext. Reading it here lets the watch converge on the true state
    /// (including workout-ended → tear the session down) even when neither app can do live
    /// messaging — the gap that left the HK session (and the watch-face indicator) stuck on.
    func ingestLatestApplicationContext() {
        let ctx = WCSession.default.receivedApplicationContext
        guard !ctx.isEmpty else { return }
        handleIncomingMessage(ctx)
    }

    func sendHeartbeat() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["path": WatchPaths.wearToPhoneHeartbeat]
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
        if snapshot == nil {
            requestSnapshotFromPhone()
        }
    }

    func requestSnapshotFromPhone() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        let message: [String: Any] = ["path": WatchPaths.wearToPhoneSnapshotRequest]
        // Use a reply handler: the phone replies with the latest snapshot on THIS message's
        // channel, which works even when the watch app is backgrounded. (A separate
        // phone->watch sendMessage reply would require the watch to be reachable, which it
        // isn't when you end on the phone with your wrist down — that's why ending on the
        // phone didn't tear the watch session down.)
        session.sendMessage(
            message,
            replyHandler: { [weak self] reply in
                guard let data = reply["data"] as? Data else { return }
                DispatchQueue.main.async {
                    self?.handleIncomingMessage([
                        "path": WatchPaths.phoneToWearSnapshot,
                        "data": data,
                    ])
                }
            },
            errorHandler: { error in
                print("SchliftWatch: snapshot request failed: \(error)")
            }
        )
    }
}
