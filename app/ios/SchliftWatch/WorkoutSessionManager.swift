import Foundation
import HealthKit

class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    var onLatestHeartRateChanged: ((Double?) -> Void)?
    var onHeartRateSample: ((Workout_V1_HeartRateSample) -> Void)?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var starting = false

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

    // Idempotent — the system caches the user's answer, so calling this repeatedly is
    // cheap and safe. We never gate on "have we already asked", so a denied-then-granted
    // sequence (user flipped the setting in Watch Settings) still takes effect.
    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion?(false)
            return
        }
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
        guard session == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            print("SchliftWatch: HealthKit unavailable on this device")
            return
        }
        guard !starting else { return }
        starting = true
        requestAuthorizationIfNeeded { [weak self] _ in
            guard let self = self else { return }
            self.starting = false
            // requestAuthorization can report failure even when read access is already
            // granted from a prior run. Attempt to start regardless — HK will silently
            // emit zero samples if read access is actually denied, and the HR watchdog
            // in PhoneConnector will surface that.
            self.startSession()
        }
    }

    func restart() {
        endSessionIfActive()
        ensureSessionActive()
    }

    private func startSession() {
        guard session == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            self.session = session
            self.builder = builder

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("SchliftWatch: Failed to begin workout collection: \(error)")
                } else {
                    print("SchliftWatch: Workout collection started success=\(success)")
                }
            }
        } catch {
            print("SchliftWatch: Failed to create workout session: \(error)")
            self.session = nil
            self.builder = nil
        }
    }

    func endSessionIfActive() {
        guard let session = session else { return }
        let builder = builder
        session.end()
        builder?.endCollection(withEnd: Date()) { _, error in
            if let error = error {
                print("SchliftWatch: Failed to end workout collection: \(error)")
            }
            builder?.discardWorkout()
        }
        self.session = nil
        self.builder = nil
        DispatchQueue.main.async { [weak self] in
            self?.onLatestHeartRateChanged?(nil)
        }
    }

    // MARK: - HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("SchliftWatch: Workout session state \(fromState.rawValue) → \(toState.rawValue)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("SchliftWatch: Workout session failed: \(error)")
        session = nil
        builder = nil
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
}
