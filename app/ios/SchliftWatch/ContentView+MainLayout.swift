import SwiftUI

/// What `workoutView` hands to `mainLayout`.
struct MainLayoutInput {
    let data: Workout_V1_WearWorkoutSnapshot
    let now: Date
    let currentSet: Workout_V1_ProposedSet?
    let completeTemplate: Workout_V1_WearAction?
    let isLiftingCompleteMode: Bool
    let primaryAction: Workout_V1_WearAction?
}

/// Button captions derived from the current set.
struct MainLayoutButtonText {
    let repsWeightText: String
    let weightOnlyText: String
    let startButtonTitle: String
    let completeButtonText: String
}

/// The displayed state label and the colours that follow from it.
struct MainLayoutStateStyle {
    let effectiveStateLabel: String
    let stateAccentColor: Color?
    let timerColor: Color
    let buttonBackgroundColor: Color
    let buttonContentColor: Color
}

/// Per-render values: rep picker bounds, heart-rate colour and the live timer texts.
struct MainLayoutLiveValues {
    let repOptionMax: Int
    let initialReps: Int
    let hrColor: Color
    let liveYouTimerText: String
    let liveElapsedText: String
    let groupProgressText: String
    let setsLeftText: String
}

extension ContentView {
    private var nextUpText: String? {
        guard let snapshot = connector.snapshot,
              !snapshot.nextUpEmoji.isEmpty
        else {
            return nil
        }
        return snapshot.nextUpEmoji
    }

    @ViewBuilder
    func mainLayout(_ input: MainLayoutInput) -> some View {
        let buttonText = mainLayoutButtonText(currentSet: input.currentSet)
        let style = mainLayoutStateStyle(data: input.data)
        let live = mainLayoutLiveValues(data: input.data, currentSet: input.currentSet)
        let isLiftingCompleteMode = input.isLiftingCompleteMode

        HStack(spacing: 0) {
            // Left column: stats
            statsColumn(now: input.now, style: style, live: live)

            // Right column: action button or rep picker
            if !isLiftingCompleteMode {
                // Simple action button
                startButton(input: input, buttonText: buttonText, style: style, live: live)
            } else {
                // Rep picker + complete button
                completeButton(input: input, buttonText: buttonText, style: style, live: live)
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    private func mainLayoutButtonText(currentSet: Workout_V1_ProposedSet?) -> MainLayoutButtonText {
        let exerciseName = formatExerciseName(currentSet?.exercise)
        let repsWeightText: String = {
            guard let set = currentSet else { return "" }
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
        return MainLayoutButtonText(
            repsWeightText: repsWeightText,
            weightOnlyText: weightOnlyText,
            startButtonTitle: startButtonTitle,
            completeButtonText: completeButtonText
        )
    }

    private func mainLayoutStateStyle(data: Workout_V1_WearWorkoutSnapshot) -> MainLayoutStateStyle {
        let effectiveStateLabel = deriveEffectiveStateLabel(
            data,
            currentApiNowMs: connector.synchronizedNowMs()
        )
        let stateAccentColor = watchStateAccentColor(effectiveStateLabel)
        let isResting = data.state == .resting && effectiveStateLabel == "Resting"
        let timerColor: Color = {
            if !data.youCard.timerText.isEmpty, let accent = stateAccentColor {
                return accent
            }
            if isResting {
                return Color(red: 0x86 / 255, green: 0xEF / 255, blue: 0xAC / 255)
            }
            return .white
        }()
        let buttonBackgroundColor = stateAccentColor ?? .white
        let buttonContentColor: Color = stateAccentColor != nil ? .white : .black
        return MainLayoutStateStyle(
            effectiveStateLabel: effectiveStateLabel,
            stateAccentColor: stateAccentColor,
            timerColor: timerColor,
            buttonBackgroundColor: buttonBackgroundColor,
            buttonContentColor: buttonContentColor
        )
    }

    private func mainLayoutLiveValues(
        data: Workout_V1_WearWorkoutSnapshot,
        currentSet: Workout_V1_ProposedSet?
    ) -> MainLayoutLiveValues {
        let repOptionMax = 100
        let initialReps = min(max(Int(currentSet?.targetReps ?? 0), 0), repOptionMax)

        let hrColor = heartRateColor(connector.latestBpm)
        let liveYouTimerText = isLuminanceReduced
            ? ""
            : deriveYouTimerText(data, currentApiNowMs: connector.synchronizedNowMs())
        let liveElapsedText = deriveElapsedText(
            data,
            currentApiNowMs: connector.synchronizedNowMs(),
            hideSeconds: isLuminanceReduced
        )
        let groupProgressText = formatGroupProgress(data.youCard, displaySet: currentSet)
        let setsLeftText = formatSetsLeft(data.youCard, displaySet: currentSet)
        return MainLayoutLiveValues(
            repOptionMax: repOptionMax,
            initialReps: initialReps,
            hrColor: hrColor,
            liveYouTimerText: liveYouTimerText,
            liveElapsedText: liveElapsedText,
            groupProgressText: groupProgressText,
            setsLeftText: setsLeftText
        )
    }

    @ViewBuilder
    private func statsColumn(
        now: Date,
        style: MainLayoutStateStyle,
        live: MainLayoutLiveValues
    ) -> some View {
        let effectiveStateLabel = style.effectiveStateLabel
        let stateAccentColor = style.stateAccentColor
        let timerColor = style.timerColor
        let hrColor = live.hrColor
        let liveYouTimerText = live.liveYouTimerText
        let liveElapsedText = live.liveElapsedText

        VStack(alignment: .trailing, spacing: 4) {
            if !liveYouTimerText.isEmpty {
                Text(liveYouTimerText)
                    .font(displayFontName(size: 34))
                    .foregroundColor(timerColor)
                    .watchAutoShrink()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(effectiveStateLabel)
                .font(displayFontName(size: 19, weight: .medium))
                .foregroundColor(stateAccentColor ?? .white)
                .watchAutoShrink(minScale: 0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if !liveYouTimerText.isEmpty {
                statLine(
                    text: formatNowClock(now),
                    systemImage: "clock",
                    color: Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255),
                    fontSize: 18
                )
            }

            statLine(
                text: liveElapsedText,
                systemImage: "hourglass.bottomhalf.filled",
                color: Color(red: 0xCB / 255, green: 0xD5 / 255, blue: 0xE1 / 255),
                fontSize: 19
            )

            statLine(
                text: connector.latestBpm.map { "\(Int($0))" } ?? "--",
                systemImage: "heart.fill",
                color: hrColor,
                fontSize: 21
            )

            if let nextUp = nextUpText {
                statLine(
                    text: nextUp,
                    systemImage: "person.fill",
                    color: Color(red: 0x9C / 255, green: 0xA3 / 255, blue: 0xAF / 255),
                    fontSize: 18
                )
            }
        }
        .frame(maxHeight: .infinity)
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 6))
    }

    private func statLine(text: String, systemImage: String, color: Color, fontSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.custom(bodyFont, size: fontSize).weight(.medium))
                .foregroundColor(color)
                .watchAutoShrink(minScale: 0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Image(systemName: systemImage)
                .foregroundColor(color)
                .font(.system(size: fontSize * 0.7))
        }
    }
}
