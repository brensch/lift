import Foundation
import HealthKit

class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    var onLatestHeartRateChanged: ((Double?) -> Void)?
    var onHeartRateSample: ((Workout_V1_HeartRateSample) -> Void)?
    // Reports the raw HKWorkoutSessionState on every transition, so the UI can surface what
    // the session is actually doing (running/stopped/ended) instead of us guessing.
    var onSessionStateChanged: ((Int) -> Void)?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var starting = false
    private var currentSessionState: HKWorkoutSessionState = .notStarted
    private var builderCollectionStarted = false
    // True while a graceful end is in flight (stopActivity → .stopped → discard → end()).
    private var endingInProgress = false

    private var isSessionRunning: Bool {
        session != nil &&
        builder != nil &&
        builderCollectionStarted &&
        currentSessionState == .running
    }

    func ensureSessionActive() {
        guard !isSessionRunning else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            print("SchliftWatch: HealthKit unavailable on this device")
            return
        }
        guard !starting else { return }
        starting = true
        if session != nil || builder != nil {
            print(
                "SchliftWatch: Resetting unhealthy workout session before restart " +
                "state=\(currentSessionState.rawValue) collectionStarted=\(builderCollectionStarted)"
            )
            tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: true)
        }
        // HealthKit authorization is requested ONCE by the phone (the Flutter `health`
        // plugin) before the watch is launched; auth is shared across the paired app, so we
        // do not request it again here. A second native request from the watch was racing
        // the phone's grant and leaving heart-rate-read / workout-share toggles unset. Just
        // start — HK silently yields no samples if access was actually denied, which the HR
        // watchdog surfaces.
        startSession()
    }

    func restart() {
        tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: true)
        ensureSessionActive()
    }

    private func startSession() {
        guard session == nil, builder == nil else {
            starting = false
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let startDate = Date()
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            self.session = session
            self.builder = builder
            currentSessionState = .prepared
            builderCollectionStarted = false

            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { [weak self] success, error in
                guard let self = self else { return }
                self.starting = false
                if let error = error {
                    print("SchliftWatch: Failed to begin workout collection: \(error)")
                    self.tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: true)
                } else if !success {
                    print("SchliftWatch: Workout collection reported success=false")
                    self.tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: true)
                } else {
                    self.builderCollectionStarted = true
                    print("SchliftWatch: Workout collection started success=\(success)")
                }
            }
        } catch {
            print("SchliftWatch: Failed to create workout session: \(error)")
            starting = false
            tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: true)
        }
    }

    func endSessionIfActive() {
        guard let currentSession = session else {
            // Builder without a session (rare) — just discard and reset.
            builder?.discardWorkout()
            resetSessionState()
            DispatchQueue.main.async { [weak self] in self?.onLatestHeartRateChanged?(nil) }
            return
        }
        DispatchQueue.main.async { [weak self] in self?.onLatestHeartRateChanged?(nil) }
        // Apple's documented end sequence for a LIVE-builder session:
        //   stopActivity → (.stopped) → stop+discard the builder → end() → (.ended) → cleanup.
        // Calling end() directly while the live data source is still collecting can leave the
        // session stuck in .stopped and never reach .ended, so the app keeps its
        // workout-processing background runtime (the persistent indicator) alive. We drive the
        // rest from the didChangeTo delegate.
        switch currentSessionState {
        case .running, .prepared, .paused:
            currentSession.stopActivity(with: Date())
        default:
            finalizeStoppedSession()
        }
    }

    // After the session reaches .stopped: stop the live builder (discardWorkout — no save,
    // no write auth needed, the phone persists the workout) and then end() the session so it
    // transitions to .ended and releases the background runtime.
    private func finalizeStoppedSession() {
        guard !endingInProgress else { return }
        endingInProgress = true
        builder?.discardWorkout()
        session?.end()
    }

    private func resetSessionState() {
        session = nil
        builder = nil
        starting = false
        endingInProgress = false
        builderCollectionStarted = false
        currentSessionState = .notStarted
    }

    // MARK: - HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        currentSessionState = toState
        print("SchliftWatch: Workout session state \(fromState.rawValue) → \(toState.rawValue)")
        DispatchQueue.main.async { [weak self] in self?.onSessionStateChanged?(toState.rawValue) }
        // Only drive teardown for the session we currently own. The force path
        // (tearDownCurrentSession) nils `session` first, so its transitions fall through here.
        guard workoutSession === session else { return }
        switch toState {
        case .stopped:
            // Reached .stopped (from stopActivity) — finalize the builder and end the session.
            finalizeStoppedSession()
        case .ended:
            // Fully ended — background runtime released. Drop references.
            resetSessionState()
        default:
            break
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("SchliftWatch: Workout session failed: \(error)")
        starting = false
        tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: false)
        // Auto-retry once on next watchdog tick by leaving state clean; the
        // PhoneConnector watchdog will call ensureSessionActive again within 10s.
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity() else {
            return
        }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        let sampleTimestamp: Int64
        if let interval = statistics.mostRecentQuantityDateInterval() {
            sampleTimestamp = Int64(interval.start.timeIntervalSince1970 * 1000)
        } else {
            sampleTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
        }

        var hrSample = Workout_V1_HeartRateSample()
        hrSample.sampledAt = sampleTimestamp
        hrSample.bpm = Float(bpm)
        hrSample.availability = .available

        onHeartRateSample?(hrSample)

        DispatchQueue.main.async { [weak self] in
            self?.onLatestHeartRateChanged?(bpm)
        }
    }

    // Immediate, forced teardown — used for restart/error paths (NOT the user-initiated end,
    // which uses the graceful stopActivity flow above). Order matters: discard the live builder
    // FIRST (stops the data source) so the session can actually reach .ended when we end() it;
    // ending before the source stops can strand the session in .stopped (a zombie that keeps
    // the app's background runtime alive). References are nil'd up front, so this session's
    // later delegate transitions fall through (workoutSession !== session).
    private func tearDownCurrentSession(clearDisplayedHeartRate: Bool, endUnderlyingSession: Bool) {
        let existingSession = session
        let existingBuilder = builder

        session = nil
        builder = nil
        starting = false
        endingInProgress = false
        currentSessionState = .notStarted
        builderCollectionStarted = false

        existingBuilder?.discardWorkout()
        if endUnderlyingSession {
            existingSession?.end()
        }

        guard clearDisplayedHeartRate else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onLatestHeartRateChanged?(nil)
        }
    }
}
