import SwiftUI

// Match mobile app workout state accents:
private let mobileLiftingGreen = Color(red: 0x16/255, green: 0xA3/255, blue: 0x4A/255) // #16A34A
private let mobileRestingBlue = Color(red: 0x3B/255, green: 0x82/255, blue: 0xF6/255) // #3B82F6
private let mobileYappingPink = Color(red: 0xEC/255, green: 0x48/255, blue: 0x99/255) // #EC4899

// Custom fonts — registered via Info.plist UIAppFonts
private let bodyFont = "Manrope-Variable"
private let displayFont = "SpaceGrotesk-Variable"

private func bodyFontName() -> Font {
    .custom(bodyFont, size: 14).weight(.medium)
}

private func displayFontName(size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .custom(displayFont, size: size).weight(weight)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @EnvironmentObject var connector: PhoneConnector

    @State private var selectedReps: Int = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 60 : 1)) { context in
            Group {
                if let snapshot = connector.snapshot {
                    workoutView(snapshot, now: context.date)
                } else {
                    Text("Waiting for phone")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            connector.setUIVisible(true)
        }
        .onDisappear {
            connector.setUIVisible(false)
        }
        .onChange(of: scenePhase) { newPhase in
            connector.setUIVisible(newPhase == .active)
        }
    }

    @ViewBuilder
    private func workoutView(_ data: Workout_V1_WearWorkoutSnapshot, now: Date) -> some View {
        let currentSet: Workout_V1_ProposedSet? = data.youCard.hasDisplaySet ? data.youCard.displaySet : nil
        let completeTemplate = data.actions.first { $0.type == .completeSet }
        let isLiftingCompleteMode = data.state == .lifting && currentSet != nil && completeTemplate != nil
        let primaryAction = data.actions.first { $0.style == .primary } ?? data.actions.first
        let completionSummary: Workout_V1_WearCompletionSummary? = data.hasCompletionSummary ? data.completionSummary : nil

        if data.state == .allDone, let summary = completionSummary {
            workoutCompleteScreen(
                summary: summary,
                onPrimary: primaryAction.map { action in { connector.sendIntent(action: action) } },
                primaryLabel: primaryAction?.label ?? "Done"
            )
        } else {
            mainLayout(
                data: data,
                now: now,
                currentSet: currentSet,
                completeTemplate: completeTemplate,
                isLiftingCompleteMode: isLiftingCompleteMode,
                primaryAction: primaryAction
            )
        }
    }

    @ViewBuilder
    private func mainLayout(
        data: Workout_V1_WearWorkoutSnapshot,
        now: Date,
        currentSet: Workout_V1_ProposedSet?,
        completeTemplate: Workout_V1_WearAction?,
        isLiftingCompleteMode: Bool,
        primaryAction: Workout_V1_WearAction?
    ) -> some View {
        let isAmrap = currentSet?.isAmrap ?? false
        let exerciseName = formatExerciseName(currentSet?.exercise)
        let repsWeightText: String = {
            guard let set = currentSet else { return "" }
            if isAmrap {
                return "AMRAPx\(Int(set.targetWeight))"
            }
            return "\(set.targetReps)x\(Int(set.targetWeight))"
        }()
        let weightOnlyText: String = {
            guard let set = currentSet else { return "" }
            return "x\(Int(set.targetWeight))"
        }()
        let startButtonTitle: String = {
            if currentSet != nil {
                return "Start\n\(exerciseName)"
            }
            return "Start"
        }()
        let completeButtonText = "Complete\n\(exerciseName)"

        let stateAccentColor = watchStateAccentColor(data.youCard.stateLabel)
        let isResting = data.state == .resting
        let timerColor: Color = {
            if !data.youCard.timerText.isEmpty, let accent = stateAccentColor {
                return accent
            }
            if isResting { return Color(red: 0x86/255, green: 0xEF/255, blue: 0xAC/255) }
            return .white
        }()
        let buttonBackgroundColor = stateAccentColor ?? .white
        let buttonContentColor: Color = stateAccentColor != nil ? .white : .black

        let maxReps = isAmrap ? 30 : Int(currentSet?.targetReps ?? 0)
        let repOptionMax = isAmrap ? 30 : max(maxReps * 2, 0)
        let initialReps = isAmrap ? min(Int(currentSet?.targetReps ?? 0), 30) : max(maxReps, 0)

        let hrColor = heartRateColor(connector.latestBpm)
        let liveYouTimerText = isLuminanceReduced ? "" : deriveYouTimerText(data, currentApiNowMs: connector.synchronizedNowMs())
        let liveElapsedText = deriveElapsedText(
            data,
            currentApiNowMs: connector.synchronizedNowMs(),
            hideSeconds: isLuminanceReduced
        )
        let groupProgressText = formatGroupProgress(data.youCard)
        let setsLeftText = formatSetsLeft(data.youCard)

        HStack(spacing: 0) {
            // Left column: stats
            VStack(alignment: .trailing, spacing: 4) {
                if !liveYouTimerText.isEmpty {
                    Text(liveYouTimerText)
                        .font(displayFontName(size: 34))
                        .foregroundColor(timerColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Text(data.youCard.stateLabel)
                    .font(displayFontName(size: 19, weight: .medium))
                    .foregroundColor(stateAccentColor ?? .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if !liveYouTimerText.isEmpty {
                    statLine(
                        text: formatNowClock(now),
                        systemImage: "clock",
                        color: Color(red: 0xE5/255, green: 0xE7/255, blue: 0xEB/255),
                        fontSize: 18
                    )
                }

                statLine(
                    text: liveElapsedText,
                    systemImage: "hourglass.bottomhalf.filled",
                    color: Color(red: 0xCB/255, green: 0xD5/255, blue: 0xE1/255),
                    fontSize: 19
                )

                statLine(
                    text: connector.latestBpm.map { "\(Int($0))" } ?? "--",
                    systemImage: "heart.fill",
                    color: hrColor,
                    fontSize: 21
                )
            }
            .frame(maxHeight: .infinity)
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 6))

            // Right column: action button or rep picker
            if !isLiftingCompleteMode {
                // Simple action button
                Button(action: {
                    if let action = primaryAction, !connector.isActionPending {
                        connector.sendIntent(action: action)
                    }
                }) {
                    ZStack {
                        if connector.isActionPending {
                            ProgressView()
                                .tint(buttonContentColor)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(startButtonTitle)
                                    .font(displayFontName(size: 18))
                                    .foregroundColor(buttonContentColor)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer().frame(height: 8)

                                Text(repsWeightText)
                                    .font(displayFontName(size: 24))
                                    .foregroundColor(buttonContentColor)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if !groupProgressText.isEmpty {
                                    Spacer().frame(height: 6)
                                    Text(groupProgressText)
                                        .font(displayFontName(size: 16, weight: .medium))
                                        .foregroundColor(buttonContentColor.opacity(0.9))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if !setsLeftText.isEmpty {
                                        Text(setsLeftText)
                                            .font(.custom(bodyFont, size: 12).weight(.medium))
                                            .foregroundColor(buttonContentColor.opacity(0.72))
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(.leading, 10)
                            .padding(.trailing, 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .buttonStyle(.plain)
                .background(buttonBackgroundColor)
                .disabled(primaryAction == nil || connector.isActionPending)
            } else {
                // Rep picker + complete button
                Button(action: {
                    if let set = currentSet, let template = completeTemplate, !connector.isActionPending {
                        var action = template
                        action.setID = set.id
                        action.reps = Int32(selectedReps)
                        action.actualWeight = template.actualWeight > 0 ? template.actualWeight : set.targetWeight
                        connector.sendIntent(action: action)
                    }
                }) {
                    ZStack {
                        if connector.isActionPending {
                            ProgressView()
                                .tint(buttonContentColor)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(completeButtonText)
                                    .font(displayFontName(size: 18))
                                    .foregroundColor(buttonContentColor)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Spacer().frame(height: 6)

                                HStack(alignment: .center, spacing: 0) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(buttonContentColor.opacity(0.45), lineWidth: 1)
                                            .frame(width: 40, height: 94)

                                        Text("\(selectedReps)")
                                            .font(displayFontName(size: 40))
                                            .foregroundColor(buttonContentColor)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 40, height: 94)
                                    .focusable()
                                    .digitalCrownRotation(
                                        detent: $selectedReps,
                                        from: 0,
                                        through: repOptionMax,
                                        by: 1,
                                        sensitivity: .medium
                                    )

                                    Text(weightOnlyText)
                                        .font(displayFontName(size: 28))
                                        .foregroundColor(buttonContentColor)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if !groupProgressText.isEmpty {
                                    Spacer().frame(height: 6)
                                    Text(groupProgressText)
                                        .font(displayFontName(size: 16, weight: .medium))
                                        .foregroundColor(buttonContentColor.opacity(0.9))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if !setsLeftText.isEmpty {
                                        Text(setsLeftText)
                                            .font(.custom(bodyFont, size: 12).weight(.medium))
                                            .foregroundColor(buttonContentColor.opacity(0.72))
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(.leading, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .buttonStyle(.plain)
                .background(buttonBackgroundColor)
                .disabled(connector.isActionPending)
                .onAppear {
                    selectedReps = initialReps
                }
                .onChange(of: currentSet?.id) { _ in
                    selectedReps = initialReps
                }
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func statLine(text: String, systemImage: String, color: Color, fontSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.custom(bodyFont, size: fontSize).weight(.medium))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Image(systemName: systemImage)
                .foregroundColor(color)
                .font(.system(size: fontSize * 0.7))
        }
    }

    @ViewBuilder
    private func workoutCompleteScreen(
        summary: Workout_V1_WearCompletionSummary,
        onPrimary: (() -> Void)?,
        primaryLabel: String
    ) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("Complete")
                    .font(displayFontName(size: 26))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer().frame(height: 6)

                completionMetric(label: "Time", value: summary.durationText)
                completionMetric(label: "Sets", value: "\(summary.completedWorkingSets)")
                completionMetric(label: "Vol", value: "\(summary.totalVolumeLb)lb")
            }
            .frame(maxHeight: .infinity)
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 6))
            .layoutPriority(2)

            Button(action: { onPrimary?() }) {
                Text(primaryLabel)
                    .font(displayFontName(size: 16))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.white)
            .disabled(onPrimary == nil)
            .layoutPriority(1)
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func completionMetric(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(bodyFont, size: 13))
                .foregroundColor(Color(red: 0x9C/255, green: 0xA3/255, blue: 0xAF/255))

            Spacer()

            Text(value)
                .font(displayFontName(size: 18))
                .foregroundColor(.white)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Helpers

private func formatNowClock() -> String {
    formatNowClock(Date())
}

private func formatNowClock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}

private func formatGroupProgress(_ card: Workout_V1_WearStatusCard) -> String {
    guard card.currentGroupSet > 0, card.totalGroupSets > 0 else { return "" }
    return "\(card.currentGroupSet)/\(card.totalGroupSets)"
}

private func formatSetsLeft(_ card: Workout_V1_WearStatusCard) -> String {
    guard card.currentGroupSet > 0, card.totalGroupSets > 0 else { return "" }
    let remaining = max(0, Int(card.totalGroupSets - card.currentGroupSet + 1))
    return remaining == 1 ? "1 set left" : "\(remaining) sets left"
}

private func deriveElapsedText(
    _ snapshot: Workout_V1_WearWorkoutSnapshot,
    currentApiNowMs: Int64,
    hideSeconds: Bool = false
) -> String {
    guard snapshot.workoutStartTime > 0 else { return snapshot.elapsedText }
    let elapsedSeconds = Int(max(0, (currentApiNowMs - (snapshot.workoutStartTime * 1000)) / 1000))
    return hideSeconds ? formatElapsedDurationNoSeconds(elapsedSeconds) : formatElapsedDuration(elapsedSeconds)
}

private func deriveYouTimerText(
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

private func watchStateAccentColor(_ stateLabel: String) -> Color? {
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

private func heartRateColor(_ bpm: Double?) -> Color {
    guard let bpm = bpm, bpm > 0 else {
        return Color(red: 0x94/255, green: 0xA3/255, blue: 0xB8/255)
    }
    switch bpm {
    case ..<110:
        return Color(red: 0x22/255, green: 0xC5/255, blue: 0x5E/255)
    case ..<140:
        return Color(red: 0xFA/255, green: 0xCC/255, blue: 0x15/255)
    case ..<165:
        return Color(red: 0xF9/255, green: 0x73/255, blue: 0x16/255)
    default:
        return Color(red: 0xEF/255, green: 0x44/255, blue: 0x44/255)
    }
}

private func formatExerciseName(_ exercise: Workout_V1_Exercise?) -> String {
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
        if character.isUppercase && !current.isEmpty {
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
