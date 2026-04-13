import Foundation
import WatchKit
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: Workout_V1_WearWorkoutSnapshot?
    @Published private(set) var latestBpm: Double?
    @Published private(set) var isActionPending = false

    private var heartbeatTimer: Timer?
    private let workoutSessionManager = WorkoutSessionManager()
    private let sensorBatchOutbox = WatchSensorBatchOutbox()
    private var lastSnapshotReceivedUptime: TimeInterval = 0
    private var lastSnapshotEmittedAtMs: Int64 = 0
    private var pendingActionTimeout: DispatchWorkItem?
    private var lastSnapshotKey: String?
    private var pendingHRSamples: [Workout_V1_HeartRateSample] = []
    private let hrLock = NSLock()
    private var pendingHRWorkoutID: String = ""

    override init() {
        super.init()
        workoutSessionManager.onLatestHeartRateChanged = { [weak self] bpm in
            self?.latestBpm = bpm
        }
        workoutSessionManager.onHeartRateSample = { [weak self] sample in
            self?.bufferAndFlushHRSample(sample)
        }
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    deinit {
        heartbeatTimer?.invalidate()
        pendingActionTimeout?.cancel()
    }

    // MARK: - Send intent to phone

    func sendIntent(action: Workout_V1_WearAction) {
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
        guard WCSession.default.isReachable else { return }
        beginPendingAction()
        sendToPhone(path: WatchPaths.wearToPhoneIntent, data: data)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("SchliftWatch: WCSession activation failed: \(error)")
        }
        if activationState == .activated, !session.receivedApplicationContext.isEmpty {
            handleIncomingMessage(session.receivedApplicationContext)
        }
        if activationState == .activated {
            flushPendingSensorBatches()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingMessage(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }

    // MARK: - Private

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let path = message["path"] as? String else { return }

        if path == WatchPaths.phoneToWearLaunch {
            DispatchQueue.main.async {
                self.setUIVisible(true)
                self.sendHeartbeat()
            }
            return
        }

        if path == WatchPaths.phoneToWearClockSync {
            guard let data = message["data"] as? Data,
                  let requestId = String(data: data, encoding: .utf8) else {
                return
            }
            let payload = "\(requestId):\(Int64(Date().timeIntervalSince1970 * 1000))"
            sendToPhone(path: WatchPaths.wearToPhoneClockSync, data: Data(payload.utf8))
            return
        }

        if path == WatchPaths.phoneToWearSensorBatchAck {
            guard let data = message["data"] as? Data,
                  let ack = try? Workout_V1_WearSensorBatchAck(serializedBytes: data) else {
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

        if preferBackgroundDelivery {
            session.transferUserInfo(message)
            return true
        }

        guard session.isReachable else {
            print("SchliftWatch: Phone not reachable")
            return false
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("SchliftWatch: Failed to send message: \(error)")
            DispatchQueue.main.async {
                self.clearPendingAction()
            }
        }
        return true
    }

    func setUIVisible(_ visible: Bool) {
        if visible {
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }

    func synchronizedNowMs() -> Int64 {
        guard lastSnapshotEmittedAtMs > 0, lastSnapshotReceivedUptime > 0 else {
            return Int64(Date().timeIntervalSince1970 * 1000)
        }
        let elapsedMs = Int64((ProcessInfo.processInfo.systemUptime - lastSnapshotReceivedUptime) * 1000)
        return lastSnapshotEmittedAtMs + max(0, elapsedMs)
    }

    private func handleSnapshot(_ snapshot: Workout_V1_WearWorkoutSnapshot) {
        let previousSnapshot = self.snapshot
        lastSnapshotReceivedUptime = ProcessInfo.processInfo.systemUptime
        lastSnapshotEmittedAtMs = snapshot.emittedAt
        let snapshotKey = meaningfulSnapshotKey(snapshot)
        if shouldPlayRestCompletionHaptic(previous: previousSnapshot, current: snapshot) {
            playRestCompletionHaptic()
        }
        self.snapshot = snapshot
        manageCompanionSession(for: snapshot)
        if isActionPending || lastSnapshotKey != snapshotKey {
            clearPendingAction()
        }
        lastSnapshotKey = snapshotKey
    }

    private func bufferAndFlushHRSample(_ sample: Workout_V1_HeartRateSample) {
        hrLock.lock()
        let workoutID = pendingHRWorkoutID
        pendingHRSamples.append(sample)
        let samples = pendingHRSamples
        pendingHRSamples.removeAll()
        hrLock.unlock()

        guard !workoutID.isEmpty else { return }

        var batch = Workout_V1_WearSensorBatch()
        batch.batchID = UUID().uuidString
        batch.workoutID = workoutID
        batch.sentAt = Int64(Date().timeIntervalSince1970 * 1000)
        batch.heartRateSamples = samples

        let enqueued = enqueueSensorBatch(batch)
        if !enqueued {
            hrLock.lock()
            pendingHRSamples.insert(contentsOf: samples, at: 0)
            hrLock.unlock()
        }
    }

    private func manageCompanionSession(for snapshot: Workout_V1_WearWorkoutSnapshot) {
        let hasEndWorkoutAction = snapshot.actions.contains { $0.type == .endWorkout }
        let activeWorkout = !snapshot.workoutID.isEmpty &&
            (snapshot.state != .allDone || hasEndWorkoutAction)
        if activeWorkout {
            hrLock.lock()
            pendingHRWorkoutID = snapshot.workoutID
            hrLock.unlock()
            workoutSessionManager.ensureSessionActive()
            flushPendingSensorBatches()
        } else {
            hrLock.lock()
            pendingHRWorkoutID = ""
            pendingHRSamples.removeAll()
            hrLock.unlock()
            workoutSessionManager.endSessionIfActive()
        }
    }

    private func meaningfulSnapshotKey(_ snapshot: Workout_V1_WearWorkoutSnapshot) -> String {
        let currentSet = snapshot.youCard.hasDisplaySet ? snapshot.youCard.displaySet : nil
        return [
            snapshot.workoutID,
            "\(snapshot.state.rawValue)",
            "\(snapshot.activeStartedAt)",
            "\(snapshot.restUntil)",
            "\(snapshot.lastRestEnd)",
            snapshot.youCard.stateLabel,
            "\(snapshot.actions.count)",
            currentSet?.id ?? "",
            currentSet.map { "\($0.targetReps)" } ?? "",
            currentSet.map { "\($0.targetWeight)" } ?? "",
        ].joined(separator: "|")
    }

    private func beginPendingAction() {
        isActionPending = true
        pendingActionTimeout?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.clearPendingAction()
        }
        pendingActionTimeout = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    private func clearPendingAction() {
        pendingActionTimeout?.cancel()
        pendingActionTimeout = nil
        isActionPending = false
    }

    private func startHeartbeat() {
        guard heartbeatTimer == nil else { return }
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func shouldPlayRestCompletionHaptic(
        previous: Workout_V1_WearWorkoutSnapshot?,
        current: Workout_V1_WearWorkoutSnapshot
    ) -> Bool {
        guard let previous else { return false }
        let previousRestUntil = previous.restUntil
        guard previousRestUntil > 0 else { return false }
        let previousWasActiveCountdown =
            previous.state == .resting &&
            previous.youCard.stateLabel == "Resting"
        guard previousWasActiveCountdown else { return false }
        guard current.youCard.stateLabel == "Yapping" else { return false }

        let currentRestEnd: Int64
        if current.lastRestEnd > 0 {
            currentRestEnd = current.lastRestEnd
        } else if current.restUntil > 0 {
            currentRestEnd = current.restUntil
        } else {
            currentRestEnd = 0
        }
        return currentRestEnd == previousRestUntil
    }

    private func playRestCompletionHaptic() {
        let device = WKInterfaceDevice.current()
        for index in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.3)) {
                device.play(.notification)
            }
        }
    }

    private func sendHeartbeat() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["path": WatchPaths.wearToPhoneHeartbeat]
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }
}

enum WatchPaths {
    static let phoneToWearSnapshot = "/schlift/phone/snapshot"
    static let phoneToWearLaunch = "/schlift/phone/launch"
    static let phoneToWearClockSync = "/schlift/phone/clock_sync"
    static let phoneToWearSensorBatchAck = "/schlift/phone/sensor_batch_ack"
    static let wearToPhoneIntent = "/schlift/wear/intent"
    static let wearToPhoneSensorBatch = "/schlift/wear/sensor_batch"
    static let wearToPhoneHeartbeat = "/schlift/wear/ui_heartbeat"
    static let wearToPhoneClockSync = "/schlift/wear/clock_sync"
}
