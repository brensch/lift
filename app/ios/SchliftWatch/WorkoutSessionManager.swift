import Foundation
import HealthKit

class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    var onLatestHeartRateChanged: ((Double?) -> Void)?
    var onHeartRateSample: ((Workout_V1_HeartRateSample) -> Void)?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var starting = false
    private var currentSessionState: HKWorkoutSessionState = .notStarted
    private var builderCollectionStarted = false

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
        guard session != nil || builder != nil else { return }
        tearDownCurrentSession(clearDisplayedHeartRate: true, endUnderlyingSession: true)
    }

    // MARK: - HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        currentSessionState = toState
        print("SchliftWatch: Workout session state \(fromState.rawValue) → \(toState.rawValue)")
        // If the session ends for any reason while we still own it (e.g. the system ends it),
        // clean up our references and discard the builder. Our own teardown nils `session`
        // first, so its later .ended fires here with workoutSession !== session and no-ops.
        if toState == .ended, workoutSession === session {
            tearDownCurrentSession(clearDisplayedHeartRate: false, endUnderlyingSession: false)
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

    private func tearDownCurrentSession(clearDisplayedHeartRate: Bool, endUnderlyingSession: Bool) {
        let existingSession = session
        let existingBuilder = builder

        session = nil
        builder = nil
        starting = false
        currentSessionState = .notStarted
        builderCollectionStarted = false

        // CORRECT end sequence for a live-builder session. Two rules learned the hard way:
        //  1. Stop the builder SYNCHRONOUSLY here — do NOT wait for the .ended delegate to do
        //     it. A session with a live builder will not reach .ended until the builder stops
        //     collecting, so deferring this deadlocks: .ended never arrives, the session sits
        //     in .stopped, and the app keeps its workout-processing background runtime alive.
        //  2. discardWorkout() (not endCollection+finishWorkout): it stops the live data
        //     source AND throws the data away — no duplicate workout (the phone saves it to
        //     Health) and no write-authorization required on the watch. This is what actually
        //     lets the session finish ending and release the watch-face "running" indicator.
        if endUnderlyingSession {
            existingSession?.end()
        }
        existingBuilder?.discardWorkout()

        guard clearDisplayedHeartRate else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onLatestHeartRateChanged?(nil)
        }
    }
}
