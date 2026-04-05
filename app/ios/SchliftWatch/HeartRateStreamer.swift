import Foundation
import HealthKit

class HeartRateStreamer: ObservableObject {
    @Published var latestBpm: Double?

    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var pendingSamples: [Workout_V1_HeartRateSample] = []
    private let lock = NSLock()
    private var flushTimer: Timer?
    private var workoutId: String?
    private weak var connector: PhoneConnector?

    func start(workoutId: String, connector: PhoneConnector) {
        if self.workoutId == workoutId && query != nil { return }
        stop()
        self.workoutId = workoutId
        self.connector = connector

        guard HKHealthStore.isHealthDataAvailable() else {
            print("SchliftWatch: HealthKit not available")
            return
        }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { [weak self] success, error in
            guard success else {
                print("SchliftWatch: HealthKit auth failed: \(String(describing: error))")
                return
            }
            self?.startQuery(heartRateType: heartRateType)
        }
    }

    func stop() {
        flushPending()
        if let query = query {
            healthStore.stop(query)
        }
        query = nil
        flushTimer?.invalidate()
        flushTimer = nil
        workoutId = nil
        connector = nil
        DispatchQueue.main.async {
            self.latestBpm = nil
        }
    }

    private func startQuery(heartRateType: HKQuantityType) {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processSamples(samples)
        }

        self.query = query
        healthStore.execute(query)

        DispatchQueue.main.async {
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.flushPending()
            }
        }
    }

    private func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        for sample in samples {
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            var hrSample = Workout_V1_HeartRateSample()
            hrSample.sampledAt = Int64(sample.startDate.timeIntervalSince1970 * 1000)
            hrSample.bpm = Float(bpm)
            hrSample.availability = .available

            lock.lock()
            pendingSamples.append(hrSample)
            lock.unlock()

            DispatchQueue.main.async {
                self.latestBpm = bpm
            }
        }
    }

    private func flushPending() {
        guard let workoutId = workoutId else { return }

        lock.lock()
        guard !pendingSamples.isEmpty else {
            lock.unlock()
            return
        }
        let samples = pendingSamples
        pendingSamples.removeAll()
        lock.unlock()

        var batch = Workout_V1_WearSensorBatch()
        batch.workoutID = workoutId
        batch.heartRateSamples = samples

        connector?.sendSensorBatch(batch)
    }
}
