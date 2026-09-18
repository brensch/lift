import SwiftUI

// Match mobile app workout state accents:
private let mobileLiftingGreen = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255) // #16A34A
private let mobileRestingBlue = Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255) // #3B82F6
private let mobileYappingPink = Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255) // #EC4899

private func formatNowClock() -> String {
    formatNowClock(Date())
}

func formatNowClock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}

func formatGroupProgress(
    _ card: Workout_V1_WearStatusCard,
    displaySet: Workout_V1_ProposedSet?
) -> String {
    guard card.currentGroupSet > 0, card.totalGroupSets > 0 else { return "" }
    let prefix = displaySet?.warmup == true ? "Warmup" : "Working"
    return "\(prefix) \(card.currentGroupSet)/\(card.totalGroupSets)"
}

func formatSetsLeft(
    _ card: Workout_V1_WearStatusCard,
    displaySet _: Workout_V1_ProposedSet?
) -> String {
    guard card.currentGroupSet > 0, card.totalGroupSets > 0 else { return "" }
    let remaining = max(0, Int(card.totalGroupSets - card.currentGroupSet + 1))
    return remaining == 1 ? "1 left" : "\(remaining) left"
}

func deriveElapsedText(
    _ snapshot: Workout_V1_WearWorkoutSnapshot,
    currentApiNowMs: Int64,
    hideSeconds: Bool = false
) -> String {
    guard snapshot.workoutStartTime > 0 else { return snapshot.elapsedText }
    let elapsedSeconds = Int(max(0, (currentApiNowMs - (snapshot.workoutStartTime * 1000)) / 1000))
    return hideSeconds ? formatElapsedDurationNoSeconds(elapsedSeconds) : formatElapsedDuration(elapsedSeconds)
}

func deriveYouTimerText(
    _ snapshot: Workout_V1_WearWorkoutSnapshot,
    currentApiNowMs: Int64
) -> String {
    switch snapshot.state {
    case .lifting:
        guard snapshot.activeStartedAt > 0 else { return snapshot.youCard.timerText }
        let elapsedSeconds = Int(max(0, (currentApiNowMs - (snapshot.activeStartedAt * 1000)) / 1000))
        return formatDuration(elapsedSeconds)
    case .resting:
        guard snapshot.restUntil > 0 else { return snapshot.youCard.timerText }
        let restUntilMs = snapshot.restUntil * 1000
        if snapshot.youCard.stateLabel == "Yapping" || restUntilMs <= currentApiNowMs {
            let elapsedSeconds = Int(max(0, (currentApiNowMs - restUntilMs) / 1000))
            return formatDuration(elapsedSeconds)
        }
        let remainingSeconds = Int(max(0, (restUntilMs - currentApiNowMs) / 1000))
        return formatDuration(remainingSeconds)
    case .ready:
        guard snapshot.youCard.stateLabel == "Yapping", snapshot.lastRestEnd > 0 else {
            return snapshot.youCard.timerText
        }
        let elapsedSeconds = Int(max(0, (currentApiNowMs - (snapshot.lastRestEnd * 1000)) / 1000))
        return formatDuration(elapsedSeconds)
    default:
        return snapshot.youCard.timerText
    }
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

private func formatElapsedDurationNoSeconds(_ totalSeconds: Int) -> String {
    let totalMinutes = totalSeconds / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
        return String(format: "%d:%02d", hours, minutes)
    }
    return "\(minutes) min"
}

/// Decide what the watch should *display* as the current state, accounting for
/// rest timers that have already expired locally even if a fresh snapshot from
/// the phone hasn't landed yet.
func deriveEffectiveStateLabel(
    _ snapshot: Workout_V1_WearWorkoutSnapshot,
    currentApiNowMs: Int64
) -> String {
    if snapshot.state == .resting, snapshot.restUntil > 0 {
        let restUntilMs = snapshot.restUntil * 1000
        if currentApiNowMs >= restUntilMs {
            return "Yapping"
        }
    }
    return snapshot.youCard.stateLabel
}

func watchStateAccentColor(_ stateLabel: String) -> Color? {
    switch stateLabel {
    case "Lifting", "Warmup":
        return mobileLiftingGreen
    case "Resting":
        return mobileRestingBlue
    case "Yapping":
        return mobileYappingPink
    default:
        return nil
    }
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

func formatExerciseName(_ exercise: Workout_V1_Exercise?) -> String {
    guard let exercise = exercise else { return "" }

    return formatProtoExerciseName(String(describing: exercise))
}

private func formatProtoExerciseName(_ raw: String) -> String {
    var name = raw.split(separator: ".").last.map(String.init) ?? raw
    if name.contains("UNRECOGNIZED") || name.contains("unknown") {
        return ""
    }
    if name.hasPrefix("EXERCISE_") {
        name = String(name.dropFirst("EXERCISE_".count))
    } else if name.hasPrefix("exercise") {
        name = String(name.dropFirst("exercise".count))
    }
    if name.lowercased() == "unspecified" || name.isEmpty {
        return ""
    }

    let words = splitExerciseNameWords(name)
    return words.map { word in
        guard let first = word.first else { return "" }
        return first.uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
}

private func splitExerciseNameWords(_ name: String) -> [String] {
    var words: [String] = []
    var current = ""

    for character in name {
        if character == "_" {
            if !current.isEmpty {
                words.append(current)
                current = ""
            }
            continue
        }
        if character.isUppercase, !current.isEmpty {
            words.append(current)
            current = String(character)
        } else {
            current.append(character)
        }
    }

    if !current.isEmpty {
        words.append(current)
    }
    return words
}
