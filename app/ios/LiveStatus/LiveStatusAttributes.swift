import ActivityKit
import Foundation

/// The live workout as a Live Activity: what the lock screen card and the
/// Dynamic Island are drawn from. Shared by the app, which starts and
/// updates it (`LiveStatusPlugin`), and the widget extension, which draws
/// it (`LiveStatusWidget`).
@available(iOS 16.2, *)
struct LiveStatusAttributes: ActivityAttributes {
    /// The workout at one stage: its words, its colours and its clock.
    struct Phase: Codable, Hashable {
        /// "Lifting", and the word short enough for the island: "Lift".
        var stage: String
        var short: String
        /// The set in hand: "Squat", and "100 kg × 5 · Set 2 of 5".
        var exercise: String
        var detail: String
        /// The stage's colour and the ink that reads on it, as 0xAARRGGBB.
        var color: UInt32
        var ink: UInt32
        /// The moment the clock counts up from, or (`countDown`) down to;
        /// nil when the stage has no clock.
        var clock: Date?
        var countDown: Bool
    }

    /// What is on show now, and what replaces it once the activity goes
    /// stale: a rest's end is the stale date, so the card moves on from
    /// resting by itself, with nothing of the app running.
    struct ContentState: Codable, Hashable {
        var now: Phase
        var then: Phase?
    }
}
