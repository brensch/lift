import Foundation
import WatchConnectivity
import WatchKit

extension PhoneConnector {
    func bufferAndFlushHRSample(_ sample: Workout_V1_HeartRateSample) {
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

    /// Periodic safety net: while a workout is active, re-assert that the HK session is
    /// running and that HR samples have arrived recently. If either check fails we ask
    /// WorkoutSessionManager to (re)start. This covers ambient-mode drops, transient HK
    /// errors, and silent HR streams.
    func startHRWatchdog() {
        guard hrWatchdogTimer == nil else { return }
        hrWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.runHRWatchdog()
        }
    }

    func stopHRWatchdog() {
        hrWatchdogTimer?.invalidate()
        hrWatchdogTimer = nil
        lastHRSampleAtMs = 0
        hrMonitoringStartedAtMs = 0
    }

    private func runHRWatchdog() {
        // Converge on the phone's latest PUSHED state (works without reachability) so we
        // notice "workout ended" and tear the session down even when both apps are
        // backgrounded — this is the reliable phone-end teardown path.
        //
        // We deliberately do NOT restart or re-create the workout session here. Re-creating
        // it on HR gaps (which are normal indoors / from wrist position) stacked up orphaned
        // HKWorkoutSessions — the "multiple Schlift timers" zombies that kept the app active.
        // The session is created once at workout start and ended once at workout end; an HR
        // gap just means no samples for a bit, not a reason to spawn another session.
        ingestLatestApplicationContext()
        // ALSO actively pull the phone's current state. Ending on the phone while the watch is
        // backgrounded is the case that wasn't tearing down: the phone's pushed end can be
        // delayed, and the cached applicationContext may be stale. The watch app is alive
        // (the session keeps it running), so it can ask the phone — which iOS wakes to reply —
        // for the latest snapshot every tick. When that snapshot is "ended",
        // handleSnapshot -> manageCompanionSession tears the session down within ~10s.
        requestSnapshotFromPhone()
    }
}
