import Foundation

final class WatchSensorBatchOutbox {
    private let defaults: UserDefaults
    private let key = "com.brensch.schlift.watch.sensor_batch_outbox"
    private let queue = DispatchQueue(label: "com.brensch.schlift.watch.sensorbatchoutbox")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func enqueue(_ batch: Workout_V1_WearSensorBatch) -> Bool {
        queue.sync {
            var batches = loadBatchesLocked().filter { $0.batchID != batch.batchID }
            batches.append(batch)
            return saveBatchesLocked(batches)
        }
    }

    func acknowledge(_ ack: Workout_V1_WearSensorBatchAck) {
        queue.sync {
            let batches = loadBatchesLocked().filter { $0.batchID != ack.batchID }
            _ = saveBatchesLocked(batches)
        }
    }

    func pendingBatches() -> [Workout_V1_WearSensorBatch] {
        queue.sync {
            loadBatchesLocked()
        }
    }

    func remove(batchID: String) {
        queue.sync {
            let batches = loadBatchesLocked().filter { $0.batchID != batchID }
            _ = saveBatchesLocked(batches)
        }
    }

    private func loadBatchesLocked() -> [Workout_V1_WearSensorBatch] {
        guard let encoded = defaults.array(forKey: key) as? [String] else { return [] }
        return encoded.compactMap { entry in
            guard let data = Data(base64Encoded: entry) else { return nil }
            return try? Workout_V1_WearSensorBatch(serializedBytes: data)
        }
    }

    private func saveBatchesLocked(_ batches: [Workout_V1_WearSensorBatch]) -> Bool {
        let encoded = batches.compactMap { batch -> String? in
            guard let data = try? batch.serializedData() else { return nil }
            return data.base64EncodedString()
        }
        defaults.set(encoded, forKey: key)
        return true
    }
}
