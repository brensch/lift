import SwiftUI

/// The plan's colours (docs/plans/one-tap-sets.md, section 8): black background,
/// no accent on Ready, blue resting, amber effort question, green done.
enum WatchPalette {
    static let grey = Color(red: 0x9C / 255, green: 0xA3 / 255, blue: 0xAF / 255) // #9CA3AF
    static let restingBlue = Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255) // #3B82F6
    static let yappingPink = Color(red: 0xD9 / 255, green: 0x4F / 255, blue: 0x8C / 255) // #D94F8C
    static let liftingOrange = Color(red: 0xFF / 255, green: 0x4F / 255, blue: 0x00 / 255) // #FF4F00
    static let doneGreen = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255) // #16A34A
}

/// Elapsed workout time, counted live from the phone's start time so it ticks
/// between snapshots; falls back to the phone's rendered text.
func deriveElapsedText(_ snapshot: Workout_V1_WearWorkoutSnapshot, currentApiNowMs: Int64) -> String {
    guard snapshot.workoutStartTime > 0 else { return snapshot.elapsedText }
    let elapsedSeconds = Int(max(0, (currentApiNowMs - (snapshot.workoutStartTime * 1000)) / 1000))
    return formatElapsedDuration(elapsedSeconds)
}

/// The Lifting screen's timer: a count-up from Start.
func deriveLiftingTimer(_ snapshot: Workout_V1_WearWorkoutSnapshot, currentApiNowMs: Int64) -> String {
    guard snapshot.liftingStartedAt > 0 else { return snapshot.youCard.timerText }
    let seconds = Int(max(0, (currentApiNowMs - snapshot.liftingStartedAt * 1000) / 1000))
    return formatElapsedDuration(seconds)
}

/// The Rest screen's timer: a countdown to `restUntil` while it is ahead, then a
/// count-up from it (yapping) until the next Start. `restUntil` stays the rest's
/// end after the countdown runs out, which is what the count-up runs from.
struct RestTimer {
    let text: String
    let restEnded: Bool
}

func deriveRestTimer(_ snapshot: Workout_V1_WearWorkoutSnapshot, currentApiNowMs: Int64) -> RestTimer {
    guard snapshot.restUntil > 0 else {
        return RestTimer(text: snapshot.youCard.timerText, restEnded: snapshot.state != .resting)
    }
    let restUntilMs = snapshot.restUntil * 1000
    if currentApiNowMs < restUntilMs {
        // Round up so the countdown shows 0:01 for its last second, then flips.
        let remainingSeconds = Int((restUntilMs - currentApiNowMs + 999) / 1000)
        return RestTimer(text: formatDuration(remainingSeconds), restEnded: false)
    }
    let overSeconds = Int((currentApiNowMs - restUntilMs) / 1000)
    return RestTimer(text: formatElapsedDuration(overSeconds), restEnded: true)
}

func formatBpm(_ bpm: Double?) -> String {
    bpm.map { "\(Int($0))" } ?? "--"
}

private func formatDuration(_ totalSeconds: Int) -> String {
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}

private func formatElapsedDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}

func heartRateColor(_ bpm: Double?) -> Color {
    guard let bpm = bpm, bpm > 0 else {
        return Color(red: 0x94 / 255, green: 0xA3 / 255, blue: 0xB8 / 255)
    }
    switch bpm {
    case ..<110:
        return Color(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255)
    case ..<140:
        return Color(red: 0xFA / 255, green: 0xCC / 255, blue: 0x15 / 255)
    case ..<165:
        return Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
    default:
        return Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    }
}
