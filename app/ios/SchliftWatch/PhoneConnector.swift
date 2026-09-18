import Foundation
import WatchConnectivity
import WatchKit

class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    /// Shared so the WKApplicationDelegate (which handles the phone-initiated launch) and
    /// the SwiftUI view tree both talk to the same connector — and so a cold background
    /// launch can reach it before any view, and therefore any @StateObject, exists.
    static let shared = PhoneConnector()

    static let restCompletionCatchUpWindowMs: Int64 = 15000

    @Published var snapshot: Workout_V1_WearWorkoutSnapshot?
    @Published private(set) var latestBpm: Double?
    @Published private(set) var isActionPending = false
    /// Live HK workout-session state, surfaced on the watch UI so we can see exactly what the
    /// session is doing (running / stopped / ended) rather than guessing.
    @Published private(set) var sessionStateLabel: String = "—"

    private var heartbeatTimer: Timer?
    private let workoutSessionManager = WorkoutSessionManager()
    let sensorBatchOutbox = WatchSensorBatchOutbox()
    private var pendingActionTimeout: DispatchWorkItem?
    var restExpiryRequest: DispatchWorkItem?
    var restCompletionHaptic: DispatchWorkItem?
    var scheduledRestCompletionForRestUntil: Int64 = 0
    var lastHapticForRestUntil: Int64 = 0
    private var lastSnapshotKey: String?
    // Set when the user taps "End Workout" on the watch (or the phone sends a dedicated end).
    // Two jobs: (1) block a stale "all sets done" snapshot from restarting the session we
    // just tore down; (2) drive the UI OPTIMISTICALLY — @Published so ContentView re-renders
    // the instant we end, showing the ended state ("Done") without waiting for the phone to
    // push a fresh snapshot back (that round-trip is unreliable, which is why the button
    // appeared to "not update"). Reset when a new/different workout starts.
    @Published private(set) var endedWorkoutID: String = ""
    var pendingHRSamples: [Workout_V1_HeartRateSample] = []
    let hrLock = NSLock()
    var pendingHRWorkoutID: String = ""
    var lastHRSampleAtMs: Int64 = 0
    var hrMonitoringStartedAtMs: Int64 = 0
    var hrWatchdogTimer: Timer?

    override init() {
        super.init()
        workoutSessionManager.onLatestHeartRateChanged = { [weak self] bpm in
            self?.latestBpm = bpm
        }
        workoutSessionManager.onHeartRateSample = { [weak self] sample in
            self?.bufferAndFlushHRSample(sample)
        }
        workoutSessionManager.onSessionStateChanged = { [weak self] raw in
            self?.sessionStateLabel = PhoneConnector.sessionStateName(raw)
        }
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// Maps HKWorkoutSessionState raw values to a short label for the on-watch readout.
    private static func sessionStateName(_ raw: Int) -> String {
        switch raw {
        case 1: return "notStarted"
        case 2: return "running"
        case 3: return "ended"
        case 4: return "paused"
        case 5: return "prepared"
        case 6: return "stopped"
        default: return "state \(raw)"
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

    /// Force-ends the watch's HK workout session right now and blocks a stale "all sets
    /// done" snapshot from restarting it. Called when the user finishes from the watch's
    /// complete screen — including when the workout was already ended on the phone but the
    /// session lingered (watchOS has no always-on listener like Android, so the phone's
    /// "ended" snapshot can be missed/delayed and the HR watchdog keeps re-asserting it).
    func endLocalSession(workoutID explicitID: String? = nil) {
        // Prefer an explicit id (from the phone's dedicated end command) so we end the right
        // workout even if our own snapshot is stale; fall back to the current snapshot.
        let id = (explicitID?.isEmpty == false ? explicitID : nil) ?? snapshot?.workoutID
        if let id = id, !id.isEmpty {
            endedWorkoutID = id
        }
        stopHRWatchdog()
        hrLock.lock()
        pendingHRWorkoutID = ""
        pendingHRSamples.removeAll()
        hrLock.unlock()
        workoutSessionManager.endSessionIfActive()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
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

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleIncomingMessage(message)
        replyHandler([:])
    }

    func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingMessage(applicationContext)
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }

    // MARK: - Private

    func setUIVisible(_ visible: Bool) {
        if visible {
            startHeartbeat()
            reconcileRestCompletionAlert()
            sendHeartbeat()
            requestSnapshotFromPhone()
            // Also pull the last state the phone PUSHED. requestSnapshotFromPhone needs the
            // phone to be reachable to reply; receivedApplicationContext is cached locally and
            // works even when the phone app is backgrounded — so this is how we reliably pick
            // up "workout ended" on wrist-raise after the user ended on the phone.
            ingestLatestApplicationContext()
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

    func handleSnapshot(_ snapshot: Workout_V1_WearWorkoutSnapshot) {
        // This workout has already been ended (and torn down) from the watch. Ignore further
        // snapshots for it so a late "all done"/"complete" push can't re-surface the stale
        // complete screen after the user has moved on. A new workout has a different id and
        // resets endedWorkoutID via manageCompanionSession, so this never blocks new sessions.
        if !endedWorkoutID.isEmpty && snapshot.workoutID == endedWorkoutID {
            return
        }
        // Drop-stale guard: out-of-order publishes from the phone (unawaited
        // sends + last-writer-wins native cache) could otherwise clobber newer
        // state with an older snapshot. `emittedAt` is monotonic per workout.
        if let existing = self.snapshot,
           existing.workoutID == snapshot.workoutID,
           snapshot.emittedAt > 0,
           snapshot.emittedAt < existing.emittedAt
        {
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

    private func manageCompanionSession(for snapshot: Workout_V1_WearWorkoutSnapshot) {
        // A new/different workout clears any prior watch-initiated end.
        if !endedWorkoutID.isEmpty, snapshot.workoutID != endedWorkoutID {
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
            // If this snapshot says the workout is ENDED (all sets done AND no End action),
            // lock it as ended. Without this, a snapshot-driven end (e.g. ending on the phone)
            // left endedWorkoutID empty, so the very next snapshot could flip activeWorkout
            // back true and RESTART the HK session — the intermittent "hk: running after
            // finishing". (The watch-button/dedicated-command paths already set it.)
            if !snapshot.workoutID.isEmpty,
               snapshot.state == .allDone,
               !hasEndWorkoutAction
            {
                endedWorkoutID = snapshot.workoutID
            }
            hrLock.lock()
            pendingHRWorkoutID = ""
            pendingHRSamples.removeAll()
            hrLock.unlock()
            stopHRWatchdog()
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

    func beginPendingAction() {
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
}

enum WatchPaths {
    static let phoneToWearSnapshot = "/schlift/phone/snapshot"
    static let phoneToWearLaunch = "/schlift/phone/launch"
    static let phoneToWearEndWorkout = "/schlift/phone/end_workout"
    static let phoneToWearClockSync = "/schlift/phone/clock_sync"
    static let phoneToWearSensorBatchAck = "/schlift/phone/sensor_batch_ack"
    static let wearToPhoneIntent = "/schlift/wear/intent"
    static let wearToPhoneSensorBatch = "/schlift/wear/sensor_batch"
    static let wearToPhoneHeartbeat = "/schlift/wear/ui_heartbeat"
    static let wearToPhoneClockSync = "/schlift/wear/clock_sync"
    static let wearToPhoneSnapshotRequest = "/schlift/wear/snapshot_request"
}
