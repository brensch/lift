import Foundation
import HealthKit

class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    var onLatestHeartRateChanged: ((Double?) -> Void)?
    var onHeartRateSample: ((Workout_V1_HeartRateSample) -> Void)?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func ensureSessionActive() {
        guard session == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }

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
            builder.beginCollection(withStart: Date()) { _, error in
                if let error = error {
                    print("SchliftWatch: Failed to begin workout collection: \(error)")
                }
            }
        } catch {
            print("SchliftWatch: Failed to create workout session: \(error)")
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
        // No-op — lifecycle managed externally
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("SchliftWatch: Workout session failed: \(error)")
        session = nil
        builder = nil
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
