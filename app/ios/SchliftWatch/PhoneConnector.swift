import Foundation
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: Workout_V1_WearWorkoutSnapshot?

    private var heartbeatTimer: Timer?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        startHeartbeat()
    }

    deinit {
        heartbeatTimer?.invalidate()
    }

    // MARK: - Send intent to phone

    func sendIntent(action: Workout_V1_WearAction) {
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
        sendToPhone(path: WatchPaths.wearToPhoneEnvelope, data: data)
    }

    func sendSensorBatch(_ batch: Workout_V1_WearSensorBatch) {
        var envelope = Workout_V1_WearToPhoneEnvelope()
        envelope.payload = .sensorBatch(batch)

        guard let data = try? envelope.serializedData() else { return }
        sendToPhone(path: WatchPaths.wearToPhoneEnvelope, data: data)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("SchliftWatch: WCSession activation failed: \(error)")
        }
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

        if path == WatchPaths.phoneToWearEnvelope {
            guard let data = message["data"] as? Data else { return }
            guard let envelope = try? Workout_V1_PhoneToWearEnvelope(serializedData: data) else { return }
            if case .snapshot(let snap) = envelope.payload {
                DispatchQueue.main.async {
                    self.snapshot = snap
                }
            }
        }
    }

    private func sendToPhone(path: String, data: Data) {
        guard WCSession.default.isReachable else {
            print("SchliftWatch: Phone not reachable")
            return
        }
        let message: [String: Any] = ["path": path, "data": data]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("SchliftWatch: Failed to send message: \(error)")
        }
    }

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
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
    static let wearToPhoneEnvelope = "/schlift/wear/envelope"
    static let wearToPhoneHeartbeat = "/schlift/wear/ui_heartbeat"
}
