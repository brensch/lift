import Foundation
import WatchKit
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    // Shared so the WKApplicationDelegate (which handles the phone-initiated launch) and
    // the SwiftUI view tree both talk to the same connector — and so a cold background
    // launch can reach it before any view, and therefore any @StateObject, exists.
    static let shared = PhoneConnector()

    private static let restCompletionCatchUpWindowMs: Int64 = 15_000

    @Published var snapshot: Workout_V1_WearWorkoutSnapshot?
    @Published private(set) var latestBpm: Double?
    @Published private(set) var isActionPending = false

    private var heartbeatTimer: Timer?
    private let workoutSessionManager = WorkoutSessionManager()
    private let sensorBatchOutbox = WatchSensorBatchOutbox()
    private var pendingActionTimeout: DispatchWorkItem?
    private var restExpiryRequest: DispatchWorkItem?
    private var restCompletionHaptic: DispatchWorkItem?
    private var scheduledRestCompletionForRestUntil: Int64 = 0
    private var lastHapticForRestUntil: Int64 = 0
    private var lastSnapshotKey: String?
    // Set when the user taps "End Workout" on the watch. Until a new workout starts, we
    // treat this workout id as inactive so a stale "all sets done" snapshot (which still
    // carries an End action) can't restart the session we just tore down. This is the only
    // thing that ends the session early — finishing the planned sets (ALL_DONE without an
    // explicit end) keeps it running, since the user may add more.
    private var endedWorkoutID: String = ""
    private var pendingHRSamples: [Workout_V1_HeartRateSample] = []
    private let hrLock = NSLock()
    private var pendingHRWorkoutID: String = ""
    private var lastHRSampleAtMs: Int64 = 0
    private var hrMonitoringStartedAtMs: Int64 = 0
    private var hrWatchdogTimer: Timer?

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
        hrWatchdogTimer?.invalidate()
        pendingActionTimeout?.cancel()
        restExpiryRequest?.cancel()
        restCompletionHaptic?.cancel()
    }

    // Called from the WKApplicationDelegate when the phone cold-launches us via
    // startWatchApp(with:). We must start the HK session from this launch path (see
    // WatchAppDelegate). ensureSessionActive is idempotent, so if a snapshot has already
    // started the session this is a no-op. HR samples collected before the phone's
    // snapshot supplies a workoutID are dropped until then; the session staying active is
    // what keeps us alive in the background so the snapshot can arrive.
    func startCompanionSessionFromLaunch() {
        workoutSessionManager.ensureSessionActive()
        startHRWatchdog()
    }

    // MARK: - Send intent to phone

    func sendIntent(action: Workout_V1_WearAction) {
        // Explicit end from the watch: tear our workout session down immediately so the
        // tracking indicator clears right away, rather than waiting for the phone to echo
        // back an "ended" snapshot (which can be delayed when the watch is in the
        // background — unlike Android, watchOS has no always-on listener, and the HR
        // watchdog would otherwise keep re-asserting the session). endedWorkoutID then
        // blocks a stale "all sets done" snapshot from restarting it. We still send the
        // intent below so the phone ends the workout too.
        if action.type == .endWorkout {
            if let id = snapshot?.workoutID, !id.isEmpty {
                endedWorkoutID = id
            }
            stopHRWatchdog()
            hrLock.lock()
            pendingHRWorkoutID = ""
            pendingHRSamples.removeAll()
            hrLock.unlock()
            workoutSessionManager.endSessionIfActive()
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
            requestSnapshotFromPhone()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        DispatchQueue.main.async {
            if self.snapshot == nil {
                self.requestSnapshotFromPhone()
            }
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
            reconcileRestCompletionAlert()
            sendHeartbeat()
            requestSnapshotFromPhone()
        } else {
            stopHeartbeat()
        }
    }

    func synchronizedNowMs() -> Int64 {
        // The watch's wall clock is NTP-synced with the phone, so it is already a
        // faithful estimate of "phone now" — which is exactly what restUntil /
        // activeStartedAt / workoutStartTime (phone wall-clock seconds) are
        // compared against. We deliberately do NOT anchor on snapshot.emittedAt:
        // snapshots routinely arrive stale (the phone replies to snapshot_request
        // with cached bytes, and pushes are delayed while the phone app is
        // suspended), so anchoring would repeatedly drag this clock back to the
        // emit time and freeze/reset the on-watch timer. WearOS must anchor on
        // emittedAt only because its monotonic clock (SystemClock.elapsedRealtime)
        // is not a wall clock; the watch has no such constraint.
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func handleSnapshot(_ snapshot: Workout_V1_WearWorkoutSnapshot) {
        // Drop-stale guard: out-of-order publishes from the phone (unawaited
        // sends + last-writer-wins native cache) could otherwise clobber newer
        // state with an older snapshot. `emittedAt` is monotonic per workout.
        if let existing = self.snapshot,
           existing.workoutID == snapshot.workoutID,
           snapshot.emittedAt > 0,
           snapshot.emittedAt < existing.emittedAt {
            return
        }
        let snapshotKey = meaningfulSnapshotKey(snapshot)
        self.snapshot = snapshot
        manageCompanionSession(for: snapshot)
        if isActionPending || lastSnapshotKey != snapshotKey {
            clearPendingAction()
        }
        lastSnapshotKey = snapshotKey
        scheduleRestExpiryRequest(for: snapshot)
        reconcileRestCompletionAlert()
    }

    // Schedule a snapshot request to fire exactly when the rest timer expires so the
    // button re-enables at the precise phase boundary rather than waiting up to 3 s
    // for the next heartbeat.
    private func scheduleRestExpiryRequest(for snapshot: Workout_V1_WearWorkoutSnapshot) {
        restExpiryRequest?.cancel()
        restExpiryRequest = nil
        guard snapshot.state == .resting, snapshot.restUntil > 0 else { return }
        let nowMs = synchronizedNowMs()
        let restUntilMs = snapshot.restUntil * 1000
        let delayMs = max(0, restUntilMs - nowMs)
        let workItem = DispatchWorkItem { [weak self] in
            self?.requestSnapshotFromPhone()
        }
        restExpiryRequest = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs)), execute: workItem)
    }

    private func bufferAndFlushHRSample(_ sample: Workout_V1_HeartRateSample) {
        lastHRSampleAtMs = Int64(Date().timeIntervalSince1970 * 1000)
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
        // A new/different workout clears any prior watch-initiated end.
        if !endedWorkoutID.isEmpty && snapshot.workoutID != endedWorkoutID {
            endedWorkoutID = ""
        }
        // Finishing the planned sets (ALL_DONE) keeps the session alive while an End action
        // is still offered — the user may add more. The session ends only on an explicit
        // End Workout: either the phone drops the End action from the snapshot (handled
        // here), or the user ends from the watch (locallyEnded, set in sendIntent).
        let locallyEnded = !endedWorkoutID.isEmpty && snapshot.workoutID == endedWorkoutID
        let hasEndWorkoutAction = snapshot.actions.contains { $0.type == .endWorkout }
        let activeWorkout = !locallyEnded && !snapshot.workoutID.isEmpty &&
            (snapshot.state != .allDone || hasEndWorkoutAction)
        if activeWorkout {
            if pendingHRWorkoutID != snapshot.workoutID {
                lastHRSampleAtMs = 0
                hrMonitoringStartedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
            } else if hrMonitoringStartedAtMs == 0 {
                hrMonitoringStartedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
            }
            hrLock.lock()
            pendingHRWorkoutID = snapshot.workoutID
            hrLock.unlock()
            workoutSessionManager.ensureSessionActive()
            startHRWatchdog()
            flushPendingSensorBatches()
        } else {
            hrLock.lock()
            pendingHRWorkoutID = ""
            pendingHRSamples.removeAll()
            hrLock.unlock()
            stopHRWatchdog()
            workoutSessionManager.endSessionIfActive()
        }
    }

    // Periodic safety net: while a workout is active, re-assert that the HK session is
    // running and that HR samples have arrived recently. If either check fails we ask
    // WorkoutSessionManager to (re)start. This covers ambient-mode drops, transient HK
    // errors, and silent HR streams.
    private func startHRWatchdog() {
        guard hrWatchdogTimer == nil else { return }
        hrWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.runHRWatchdog()
        }
    }

    private func stopHRWatchdog() {
        hrWatchdogTimer?.invalidate()
        hrWatchdogTimer = nil
        lastHRSampleAtMs = 0
        hrMonitoringStartedAtMs = 0
    }

    private func runHRWatchdog() {
        // Always re-call ensureSessionActive — it's a no-op when the session is running.
        workoutSessionManager.ensureSessionActive()
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if lastHRSampleAtMs == 0,
           hrMonitoringStartedAtMs > 0,
           nowMs - hrMonitoringStartedAtMs > 25_000 {
            // 25s with no HR sample: the session is likely wedged. Restart it; if
            // the user actually denied HR access, HK keeps emitting zero samples
            // and we simply keep retrying (no nagging — we never re-request auth).
            print("SchliftWatch: No initial HR sample within 25s, restarting workout session")
            workoutSessionManager.restart()
            hrMonitoringStartedAtMs = nowMs
            return
        }
        // If we've received at least one sample and then nothing for 20s, force a restart.
        if lastHRSampleAtMs > 0, nowMs - lastHRSampleAtMs > 20_000 {
            print("SchliftWatch: HR sample silence >20s, restarting workout session")
            workoutSessionManager.restart()
            lastHRSampleAtMs = 0
            hrMonitoringStartedAtMs = nowMs
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
        // Safety timeout: the button re-enables 2s after a tap even if no fresh snapshot
        // arrives. Normal reply is <500ms, so 2s is ample and avoids the old 8s "stuck
        // grey" window users complained about.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
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

    // The watch owns the rest-end alert locally once it has a `restUntil`.
    // If the exact deadline was missed while the UI was dimmed or suspended, fire
    // once immediately on wake / next snapshot rather than depending on a new push
    // from the phone to tell us the timer already expired.
    private func reconcileRestCompletionAlert() {
        guard let snapshot else {
            cancelRestCompletionAlert()
            return
        }

        if snapshot.state == .resting, snapshot.restUntil > 0 {
            scheduleRestCompletionAlert(for: snapshot.restUntil)
            return
        }

        if snapshot.lastRestEnd > 0 {
            maybeCatchUpRestCompletionAlert(restUntil: snapshot.lastRestEnd)
        }
        cancelRestCompletionAlert()
    }

    private func scheduleRestCompletionAlert(for restUntil: Int64) {
        guard restUntil > 0 else {
            cancelRestCompletionAlert()
            return
        }
        if restUntil == lastHapticForRestUntil {
            cancelRestCompletionAlert()
            return
        }

        let nowMs = synchronizedNowMs()
        let restUntilMs = restUntil * 1000
        if nowMs >= restUntilMs {
            maybeCatchUpRestCompletionAlert(restUntil: restUntil)
            cancelRestCompletionAlert()
            return
        }

        if restUntil == scheduledRestCompletionForRestUntil, restCompletionHaptic != nil {
            return
        }

        restCompletionHaptic?.cancel()
        let delayMs = max(0, restUntilMs - nowMs)
        let workItem = DispatchWorkItem { [weak self] in
            self?.fireRestCompletionAlert(restUntil: restUntil)
        }
        restCompletionHaptic = workItem
        scheduledRestCompletionForRestUntil = restUntil
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs)), execute: workItem)
    }

    private func maybeCatchUpRestCompletionAlert(restUntil: Int64) {
        guard restUntil > 0, restUntil != lastHapticForRestUntil else { return }
        let nowMs = synchronizedNowMs()
        let restUntilMs = restUntil * 1000
        guard nowMs >= restUntilMs else { return }
        guard nowMs - restUntilMs <= PhoneConnector.restCompletionCatchUpWindowMs else {
            return
        }
        fireRestCompletionAlert(restUntil: restUntil)
    }

    private func fireRestCompletionAlert(restUntil: Int64) {
        guard restUntil > 0, restUntil != lastHapticForRestUntil else { return }
        restCompletionHaptic?.cancel()
        restCompletionHaptic = nil
        scheduledRestCompletionForRestUntil = 0
        lastHapticForRestUntil = restUntil
        playRestCompletionHaptic()
    }

    private func cancelRestCompletionAlert() {
        restCompletionHaptic?.cancel()
        restCompletionHaptic = nil
        scheduledRestCompletionForRestUntil = 0
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
        if snapshot == nil {
            requestSnapshotFromPhone()
        }
    }

    private func requestSnapshotFromPhone() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = ["path": WatchPaths.wearToPhoneSnapshotRequest]
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
    static let wearToPhoneSnapshotRequest = "/schlift/wear/snapshot_request"
}
