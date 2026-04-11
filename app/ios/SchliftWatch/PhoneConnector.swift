import Foundation
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: Workout_V1_WearWorkoutSnapshot?
    @Published private(set) var latestBpm: Double?
    @Published private(set) var isActionPending = false

    private var heartbeatTimer: Timer?
    private let heartRateStreamer = HeartRateStreamer()
    private let workoutSessionManager = WorkoutSessionManager()
    private var lastSnapshotReceivedUptime: TimeInterval = 0
    private var lastSnapshotEmittedAtMs: Int64 = 0
    private var pendingActionTimeout: DispatchWorkItem?
    private var lastSnapshotKey: String?

    override init() {
        super.init()
        heartRateStreamer.onLatestBpmChanged = { [weak self] bpm in
            self?.latestBpm = bpm
        }
        workoutSessionManager.onLatestHeartRateChanged = { [weak self] bpm in
            self?.latestBpm = bpm
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

        var envelope = Workout_V1_WearToPhoneEnvelope()
        envelope.payload = .intent(intent)

        guard let data = try? envelope.serializedData() else { return }
        guard WCSession.default.isReachable else { return }
        beginPendingAction()
        sendToPhone(path: WatchPaths.wearToPhoneEnvelope, data: data)
    }

    @discardableResult
    func sendSensorBatch(_ batch: Workout_V1_WearSensorBatch) -> Bool {
        var envelope = Workout_V1_WearToPhoneEnvelope()
        envelope.payload = .sensorBatch(batch)

        guard let data = try? envelope.serializedData() else { return false }
        return sendToPhone(
            path: WatchPaths.wearToPhoneEnvelope,
            data: data,
            preferBackgroundDelivery: true
        )
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("SchliftWatch: WCSession activation failed: \(error)")
        }
        if activationState == .activated, !session.receivedApplicationContext.isEmpty {
            handleIncomingMessage(session.receivedApplicationContext)
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

        if path == WatchPaths.phoneToWearEnvelope {
            guard let data = message["data"] as? Data else { return }
            guard let envelope = try? Workout_V1_PhoneToWearEnvelope(serializedBytes: data) else { return }
            if case .snapshot(let snap) = envelope.payload {
                DispatchQueue.main.async {
                    self.handleSnapshot(snap)
                }
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
        lastSnapshotReceivedUptime = ProcessInfo.processInfo.systemUptime
        lastSnapshotEmittedAtMs = snapshot.emittedAt
        let snapshotKey = meaningfulSnapshotKey(snapshot)
        self.snapshot = snapshot
        manageCompanionSession(for: snapshot)
        if lastSnapshotKey != snapshotKey {
            clearPendingAction()
        }
        lastSnapshotKey = snapshotKey
    }

    private func manageCompanionSession(for snapshot: Workout_V1_WearWorkoutSnapshot) {
        let hasEndWorkoutAction = snapshot.actions.contains { $0.type == .endWorkout }
        let activeWorkout = !snapshot.workoutID.isEmpty &&
            (snapshot.state != .allDone || hasEndWorkoutAction)
        if activeWorkout {
            workoutSessionManager.ensureSessionActive()
            heartRateStreamer.start(workoutId: snapshot.workoutID, connector: self)
        } else {
            heartRateStreamer.stop()
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

    private func sendHeartbeat() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["path": WatchPaths.wearToPhoneHeartbeat]
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }
}

enum WatchPaths {
    static let phoneToWearEnvelope = "/schlift/phone/envelope"
    static let phoneToWearLaunch = "/schlift/phone/launch"
    static let phoneToWearClockSync = "/schlift/phone/clock_sync"
    static let wearToPhoneEnvelope = "/schlift/wear/envelope"
    static let wearToPhoneHeartbeat = "/schlift/wear/ui_heartbeat"
    static let wearToPhoneClockSync = "/schlift/wear/clock_sync"
}
