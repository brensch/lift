import SwiftUI

/// The phone app's tokens (app/lib/theme/schlift_spec.dart).
enum WatchPalette {
    static let ground = Color(rgb: 0xDBDAD2)
    static let panel = Color(rgb: 0xEDECE5)
    static let hairline = Color(rgb: 0xA8A79F)
    static let rule = Color(rgb: 0x74746E)
    static let text = Color(rgb: 0x111111)
    static let muted = Color(rgb: 0x4A4A44)
    static let onDark = Color.white
    static let ready = Color(rgb: 0x3D8B4A)
    static let readyInk = Color(rgb: 0x2F6E3A)
    static let lifting = Color(rgb: 0xFF4F00)
    static let liftingInk = Color(rgb: 0xC23C00)
    static let resting = Color(rgb: 0x3C5FB0)
    static let yapping = Color(rgb: 0xD94F8C)
    static let yappingInk = Color(rgb: 0xB0306B)
    static let fix = Color(rgb: 0xD99A00)
    static let firstTime = Color(rgb: 0x111111)
    static let ambientText = Color(rgb: 0xB7B6AC)
}

extension Color {
    /// A colour from 0xRRGGBB.
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// A colour from "#RRGGBB"; grey if it doesn't parse.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        self.init(rgb: UInt32(digits, radix: 16) ?? 0x4A4A44)
    }
}

/// Unix milliseconds of the timeline tick being rendered. The watch's wall clock is
/// what the phone's absolute timestamps (`restUntil`, `workoutStartTime`) are
/// compared against; see `PhoneConnector.synchronizedNowMs`.
func watchNowMs(_ now: Date) -> Int64 {
    Int64(now.timeIntervalSince1970 * 1000)
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

/// Heart rate in the app's colours: easy green, working ochre, hard orange, max magenta.
func heartRateColor(_ bpm: Double?) -> Color {
    guard let bpm = bpm, bpm > 0 else { return WatchPalette.muted }
    switch bpm {
    case ..<110:
        return WatchPalette.readyInk
    case ..<140:
        return Color(rgb: 0x8D5A00)
    case ..<165:
        return WatchPalette.liftingInk
    default:
        return Color(rgb: 0xC2185B)
    }
}
