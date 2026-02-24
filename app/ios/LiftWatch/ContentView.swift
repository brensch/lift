import SwiftUI
import WatchKit

// Match mobile app workout state accents:
private let mobileLiftingPink = Color(red: 0xEC/255, green: 0x48/255, blue: 0x99/255) // #EC4899
private let mobileRestingBlue = Color(red: 0x3B/255, green: 0x82/255, blue: 0xF6/255) // #3B82F6
private let mobileYappingOrange = Color(red: 0xF9/255, green: 0x73/255, blue: 0x16/255) // #F97316

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
    @EnvironmentObject var connector: PhoneConnector
    @EnvironmentObject var heartRateStreamer: HeartRateStreamer

    @State private var currentClock = formatNowClock()
    @State private var selectedReps: Int = 0
    @State private var isStreaming = false
    @State private var lastWorkoutId = ""

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let snapshot = connector.snapshot {
                workoutView(snapshot)
            } else {
                Text("Waiting for phone")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(clockTimer) { _ in
            currentClock = formatNowClock()
        }
    }

    @ViewBuilder
    private func workoutView(_ data: Workout_V1_WearWorkoutSnapshot) -> some View {
        let currentSet: Workout_V1_ProposedSet? = data.youCard.hasDisplaySet ? data.youCard.displaySet : nil
        let completeTemplate = data.actions.first { $0.type == .completeSet }
        let isLiftingCompleteMode = data.state == .lifting && currentSet != nil && completeTemplate != nil
        let primaryAction = data.actions.first { $0.style == .primary } ?? data.actions.first
        let completionSummary: Workout_V1_WearCompletionSummary? = data.hasCompletionSummary ? data.completionSummary : nil
        let hasEndWorkoutAction = data.actions.contains { $0.type == .endWorkout }

        let _ = manageStreaming(data: data, hasEndWorkoutAction: hasEndWorkoutAction)

        if data.state == .allDone, let summary = completionSummary {
            workoutCompleteScreen(
                summary: summary,
                onPrimary: primaryAction.map { action in { connector.sendIntent(action: action) } },
                primaryLabel: primaryAction?.label ?? "Done"
            )
        } else {
            mainLayout(
                data: data,
                currentSet: currentSet,
                completeTemplate: completeTemplate,
                isLiftingCompleteMode: isLiftingCompleteMode,
                primaryAction: primaryAction
            )
        }
    }

    private func manageStreaming(data: Workout_V1_WearWorkoutSnapshot, hasEndWorkoutAction: Bool) {
        let shouldStream = !data.workoutID.isEmpty &&
            (data.state != .allDone || hasEndWorkoutAction)

        if data.workoutID != lastWorkoutId {
            DispatchQueue.main.async {
                lastWorkoutId = data.workoutID
                if !shouldStream {
                    heartRateStreamer.stop()
                    isStreaming = false
                }
            }
        }

        if shouldStream && !isStreaming {
            DispatchQueue.main.async {
                heartRateStreamer.start(workoutId: data.workoutID, connector: connector)
                isStreaming = true
            }
        } else if !shouldStream && isStreaming {
            DispatchQueue.main.async {
                heartRateStreamer.stop()
                isStreaming = false
            }
        }
    }

    @ViewBuilder
    private func mainLayout(
        data: Workout_V1_WearWorkoutSnapshot,
        currentSet: Workout_V1_ProposedSet?,
        completeTemplate: Workout_V1_WearAction?,
        isLiftingCompleteMode: Bool,
        primaryAction: Workout_V1_WearAction?
    ) -> some View {
        let isAmrap = currentSet?.isAmrap ?? false
        let exerciseName = formatExerciseName(currentSet?.exercise.name ?? "")
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
        let buttonMutedContentColor: Color = stateAccentColor != nil ? .white.opacity(0.6) : Color(red: 0x6B/255, green: 0x72/255, blue: 0x80/255)

        let maxReps = isAmrap ? 30 : Int(currentSet?.targetReps ?? 0)
        let repOptionMax = isAmrap ? 30 : max(maxReps * 2, 0)
        let initialReps = isAmrap ? min(Int(currentSet?.targetReps ?? 0), 30) : max(maxReps, 0)

        let hrColor = heartRateColor(heartRateStreamer.latestBpm)

        HStack(spacing: 0) {
            // Left column: stats
            VStack(alignment: .trailing, spacing: 4) {
                if !data.youCard.timerText.isEmpty {
                    Text(data.youCard.timerText)
                        .font(displayFontName(size: 34))
                        .foregroundColor(timerColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Text(data.youCard.stateLabel)
                    .font(displayFontName(size: 19, weight: .medium))
                    .foregroundColor(stateAccentColor ?? .white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if !data.youCard.timerText.isEmpty {
                    statLine(
                        text: currentClock,
                        systemImage: "clock",
                        color: Color(red: 0xE5/255, green: 0xE7/255, blue: 0xEB/255),
                        fontSize: 18
                    )
                }

                statLine(
                    text: data.elapsedText,
                    systemImage: "hourglass.bottomhalf.filled",
                    color: Color(red: 0xCB/255, green: 0xD5/255, blue: 0xE1/255),
                    fontSize: 19
                )

                statLine(
                    text: heartRateStreamer.latestBpm.map { "\(Int($0))" } ?? "--",
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
                    if let action = primaryAction {
                        connector.sendIntent(action: action)
                    }
                }) {
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
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(buttonBackgroundColor)
                .disabled(primaryAction == nil)
            } else {
                // Rep picker + complete button
                Button(action: {
                    if let set = currentSet, let template = completeTemplate {
                        var action = template
                        action.setID = set.id
                        action.reps = Int32(selectedReps)
                        action.actualWeight = template.actualWeight > 0 ? template.actualWeight : set.targetWeight
                        connector.sendIntent(action: action)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(completeButtonText)
                            .font(displayFontName(size: 18))
                            .foregroundColor(buttonContentColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer().frame(height: 6)

                        HStack(alignment: .center, spacing: 0) {
                            // Rep picker using Digital Crown
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
                    }
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(buttonBackgroundColor)
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
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: Date())
}

private func watchStateAccentColor(_ stateLabel: String) -> Color? {
    switch stateLabel {
    case "Lifting", "Warmup":
        return mobileLiftingPink
    case "Resting":
        return mobileRestingBlue
    case "Yapping":
        return mobileYappingOrange
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

private func formatExerciseName(_ raw: String) -> String {
    raw.replacingOccurrences(of: "EXERCISE_", with: "")
        .lowercased()
        .split(separator: "_")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}
