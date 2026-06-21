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
    // HealthKit authorization is requested at most once per app run. ensureSessionActive
    // is called repeatedly by the watchdog (every 10–25s) and on every session restart;
    // without this guard each call re-invoked requestAuthorization, which re-presented the
    // permission sheet on the wrist over and over.
    private var hasRequestedAuthorization = false

    private var isSessionRunning: Bool {
        session != nil &&
        builder != nil &&
        builderCollectionStarted &&
        currentSessionState == .running
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    // Requested once per workout, from ensureSessionActive() when the HK session is
    // (re)started. The system caches the user's answer and only presents its sheet for
    // types still not-determined, so this never nags between workouts.
    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion?(false)
            return
        }
        // Already asked this run — don't re-present the sheet (the watchdog calls this
        // every cycle). The session can still proceed; HK silently yields no samples if
        // access was actually denied, which the HR watchdog already handles.
        if hasRequestedAuthorization {
            completion?(true)
            return
        }
        hasRequestedAuthorization = true
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            if let error = error {
                print("SchliftWatch: HealthKit authorization error: \(error)")
            } else {
                print("SchliftWatch: HealthKit authorization success=\(success)")
            }
            DispatchQueue.main.async {
                completion?(success)
            }
        }
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
        requestAuthorizationIfNeeded { [weak self] _ in
            guard let self = self else { return }
            // requestAuthorization can report failure even when read access is already
            // granted from a prior run. Attempt to start regardless — HK will silently
            // emit zero samples if read access is actually denied, and the HR watchdog
            // in PhoneConnector will surface that.
            self.startSession()
        }
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
        if toState == .ended {
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
        let shouldEndCollection = builderCollectionStarted

        session = nil
        builder = nil
        starting = false
        currentSessionState = .notStarted
        builderCollectionStarted = false

        if endUnderlyingSession {
            existingSession?.end()
        }
        if shouldEndCollection {
            existingBuilder?.endCollection(withEnd: Date()) { _, error in
                if let error = error {
                    print("SchliftWatch: Failed to end workout collection: \(error)")
                }
                existingBuilder?.discardWorkout()
            }
        } else {
            existingBuilder?.discardWorkout()
        }

        guard clearDisplayedHeartRate else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onLatestHeartRateChanged?(nil)
        }
    }
}
