import Foundation
import WatchConnectivity
import WatchKit

extension PhoneConnector {
    /// Schedule a snapshot request to fire exactly when the rest timer expires so the
    /// button re-enables at the precise phase boundary rather than waiting up to 3 s
    /// for the next heartbeat.
    func scheduleRestExpiryRequest(for snapshot: Workout_V1_WearWorkoutSnapshot) {
        restExpiryRequest?.cancel()
        restExpiryRequest = nil
        guard snapshot.state == .resting, snapshot.restUntil > 0 else { return }
        let nowMs = synchronizedNowMs()
        let restUntilMs = snapshot.restUntil * 1000
        let delayMs = max(0, restUntilMs - nowMs)
        let workItem = DispatchWorkItem { [weak self] in
            self?.requestSnapshotFromPhone()
        }
        restExpiryRequest = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs)), execute: workItem)
    }

    /// The watch owns the rest-end alert locally once it has a `restUntil`.
    /// If the exact deadline was missed while the UI was dimmed or suspended, fire
    /// once immediately on wake / next snapshot rather than depending on a new push
    /// from the phone to tell us the timer already expired.
    func reconcileRestCompletionAlert() {
        guard let snapshot else {
            cancelRestCompletionAlert()
            return
        }

        if snapshot.state == .resting, snapshot.restUntil > 0 {
            scheduleRestCompletionAlert(for: snapshot.restUntil)
            return
        }

        if snapshot.lastRestEnd > 0 {
            maybeCatchUpRestCompletionAlert(restUntil: snapshot.lastRestEnd)
        }
        cancelRestCompletionAlert()
    }

    private func scheduleRestCompletionAlert(for restUntil: Int64) {
        guard restUntil > 0 else {
            cancelRestCompletionAlert()
            return
        }
        if restUntil == lastHapticForRestUntil {
            cancelRestCompletionAlert()
            return
        }

        let nowMs = synchronizedNowMs()
        let restUntilMs = restUntil * 1000
        if nowMs >= restUntilMs {
            maybeCatchUpRestCompletionAlert(restUntil: restUntil)
            cancelRestCompletionAlert()
            return
        }

        if restUntil == scheduledRestCompletionForRestUntil, restCompletionHaptic != nil {
            return
        }

        restCompletionHaptic?.cancel()
        let delayMs = max(0, restUntilMs - nowMs)
        let workItem = DispatchWorkItem { [weak self] in
            self?.fireRestCompletionAlert(restUntil: restUntil)
        }
        restCompletionHaptic = workItem
        scheduledRestCompletionForRestUntil = restUntil
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs)), execute: workItem)
    }

    private func maybeCatchUpRestCompletionAlert(restUntil: Int64) {
        guard restUntil > 0, restUntil != lastHapticForRestUntil else { return }
        let nowMs = synchronizedNowMs()
        let restUntilMs = restUntil * 1000
        guard nowMs >= restUntilMs else { return }
        guard nowMs - restUntilMs <= PhoneConnector.restCompletionCatchUpWindowMs else {
            return
        }
        fireRestCompletionAlert(restUntil: restUntil)
    }

    private func fireRestCompletionAlert(restUntil: Int64) {
        guard restUntil > 0, restUntil != lastHapticForRestUntil else { return }
        restCompletionHaptic?.cancel()
        restCompletionHaptic = nil
        scheduledRestCompletionForRestUntil = 0
        lastHapticForRestUntil = restUntil
        playRestCompletionHaptic()
    }

    private func cancelRestCompletionAlert() {
        restCompletionHaptic?.cancel()
        restCompletionHaptic = nil
        scheduledRestCompletionForRestUntil = 0
    }

    private func playRestCompletionHaptic() {
        let device = WKInterfaceDevice.current()
        for index in 0 ..< 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.3)) {
                device.play(.notification)
            }
        }
    }
}
