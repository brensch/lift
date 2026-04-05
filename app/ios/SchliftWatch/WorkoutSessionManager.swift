import Foundation
import HealthKit

class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
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
        session.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, error in
            if let error = error {
                print("SchliftWatch: Failed to end workout collection: \(error)")
            }
            self?.builder?.finishWorkout { _, error in
                if let error = error {
                    print("SchliftWatch: Failed to finish workout: \(error)")
                }
            }
        }
        self.session = nil
        self.builder = nil
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

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}
