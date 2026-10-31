import SwiftUI

/// The watch face, one layout for every live state (the "split"): information rows
/// on the left, split by thin lines (the stage and its clock, heart rate and workout
/// length, the exercise and set, the weight, the time and who's up next); the right
/// is one big button in the state's colour with the reps on it. Tap the weight for
/// the plates. For a few seconds after a set ends the button turns amber and each
/// tap takes a rep off it, a bar draining down its edge.
struct SplitScreen: View {
    @EnvironmentObject private var connector: PhoneConnector
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    @State private var showPlates = false
    @State private var fixSetID = ""
    @State private var fixReps: Int32 = 0
    @State private var lastFixTapMs: Int64 = 0

    private var card: Workout_V1_WearStatusCard { snapshot.youCard }

    private var primary: Workout_V1_WearAction? {
        snapshot.actions.first { $0.type == .completeSet } ?? snapshot.actions.first { $0.type == .startSet }
    }

    var body: some View {
        if isLuminanceReduced {
            ambient
        } else {
            // A fine tick while the fix window runs, so its bar drains smoothly.
            TimelineView(.periodic(from: now, by: fixWindowEndMs(at: watchNowMs(now)) > watchNowMs(now) ? 0.1 : 1)) { context in
                face(nowMs: connector.synchronizedNowMs(), date: context.date)
            }
            .sheet(isPresented: $showPlates) {
                PlateScreen(card: card)
            }
        }
    }

    // MARK: - The fix window

    private func fixWindowEndMs(at _: Int64) -> Int64 {
        guard snapshot.hasLastDone else { return 0 }
        return max(snapshot.lastDone.endedAt * 1000, lastFixTapMs) + 3000
    }

    private func inFixWindow(nowMs: Int64) -> Bool {
        snapshot.hasLastDone && snapshot.state != .lifting && nowMs < fixWindowEndMs(at: nowMs)
    }

    /// The reps the watch shows for the set just done: its own count once tapped,
    /// until the phone's answer catches up.
    private var shownFixReps: Int32 {
        fixSetID == snapshot.lastDone.completedSetID ? fixReps : snapshot.lastDone.reps
    }

    private func tap(nowMs: Int64) {
        if inFixWindow(nowMs: nowMs) {
            let done = snapshot.lastDone
            let reps = max(0, shownFixReps - 1)
            fixSetID = done.completedSetID
            fixReps = reps
            lastFixTapMs = nowMs
            connector.sendFix(completedSetID: done.completedSetID, reps: reps, weight: done.actualWeight)
        } else if let action = primary {
            connector.sendIntent(action: action)
        }
    }

    // MARK: - Layout

    private var stage: (label: String, labelColor: Color, color: Color, ink: Color, timer: String) {
        let nowMs = watchNowMs(now)
        let rest = deriveRestTimer(snapshot, currentApiNowMs: nowMs)
        if card.firstTime {
            return (card.stateLabel, WatchPalette.liftingInk, WatchPalette.firstTime, WatchPalette.onDark, "")
        }
        switch snapshot.state {
        case .lifting:
            return (card.stateLabel, WatchPalette.liftingInk, WatchPalette.lifting, WatchPalette.text,
                    deriveLiftingTimer(snapshot, currentApiNowMs: nowMs))
        case .resting, .yapping:
            if rest.restEnded {
                let label = card.yappingLabel.isEmpty ? card.stateLabel : card.yappingLabel
                return (label, WatchPalette.yappingInk, WatchPalette.yapping, WatchPalette.onDark, rest.text)
            }
            return (card.stateLabel, WatchPalette.resting, WatchPalette.resting, WatchPalette.onDark, rest.text)
        default:
            return (card.stateLabel, WatchPalette.readyInk, WatchPalette.ready, WatchPalette.onDark, "")
        }
    }

    private func face(nowMs: Int64, date _: Date) -> some View {
        let stage = stage
        let fixing = inFixWindow(nowMs: nowMs)
        let windowLeft = fixing ? Double(fixWindowEndMs(at: nowMs) - nowMs) / 3000 : 0
        return GeometryReader { geo in
            let faceWidth = geo.size.width
            let faceHeight = geo.size.height
            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Spacer(minLength: 0)
                        fit(stage.label.uppercased(), size: faceHeight * 0.055, color: stage.labelColor)
                        if !stage.timer.isEmpty {
                            fit(stage.timer, size: faceHeight * 0.15)
                        }
                    }
                    .padding(.trailing, 6)
                    .frame(height: faceHeight * 0.30)
                    line
                    HStack(spacing: 0) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: faceHeight * 0.05))
                                .foregroundColor(heartRateColor(connector.latestBpm))
                            fit(formatBpm(connector.latestBpm), size: faceHeight * 0.068, color: heartRateColor(connector.latestBpm))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                        Rectangle().fill(WatchPalette.hairline).frame(width: 1)
                        fit(deriveElapsedText(snapshot, currentApiNowMs: watchNowMs(now)), size: faceHeight * 0.068)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 6)
                    }
                    .frame(height: faceHeight * 0.11)
                    .background(WatchPalette.panel)
                    line
                    fit([card.exerciseName, card.setLine].filter { !$0.isEmpty }.joined(separator: " "),
                        size: faceHeight * 0.058, font: textFontName)
                        .padding(.trailing, 6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: faceHeight * 0.09)
                        .background(WatchPalette.panel)
                    line
                    Button {
                        if !card.platesText.isEmpty { showPlates = true }
                    } label: {
                        fit(card.weightText == "?" ? "?" : "\(card.weightText) \(card.unitText)", size: faceHeight * 0.13)
                            .padding(.trailing, 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .frame(height: faceHeight * 0.15)
                    .background(WatchPalette.panel)
                    line
                    VStack(alignment: .trailing, spacing: 0) {
                        fit(now.formatted(date: .omitted, time: .shortened), size: faceHeight * 0.055, color: WatchPalette.muted)
                        if !snapshot.nextUpEmoji.isEmpty {
                            fit("next \(snapshot.nextUpEmoji)", size: faceHeight * 0.052, color: WatchPalette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 3)
                    .padding(.trailing, 6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(width: faceWidth * 0.57)
                Rectangle().fill(WatchPalette.rule).frame(width: 1)
                bigButton(stage: stage, fixing: fixing, windowLeft: windowLeft, faceHeight: faceHeight, nowMs: nowMs)
            }
        }
        .background(WatchPalette.ground.ignoresSafeArea())
    }

    private func bigButton(
        stage: (label: String, labelColor: Color, color: Color, ink: Color, timer: String),
        fixing: Bool,
        windowLeft: Double,
        faceHeight: CGFloat,
        nowMs: Int64
    ) -> some View {
        let color = fixing ? WatchPalette.fix : stage.color
        let ink = fixing ? WatchPalette.text : stage.ink
        return Button {
            tap(nowMs: nowMs)
        } label: {
            HStack(spacing: 0) {
                // The fix window drains down the inner edge.
                ZStack(alignment: .bottom) {
                    Rectangle().fill(fixing ? WatchPalette.rule : color)
                    if fixing {
                        Rectangle().fill(ink).frame(height: faceHeight * CGFloat(min(max(windowLeft, 0), 1)))
                    }
                }
                .frame(width: 6)
                VStack(spacing: 4) {
                    fit(fixing ? "\(shownFixReps)" : card.repsText, size: faceHeight * 0.30, color: ink, alignment: .center)
                    fit((fixing ? snapshot.lastDone.cue : card.cue).uppercased(), size: faceHeight * 0.055, color: ink, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(color)
        }
        .buttonStyle(.plain)
        .disabled(!fixing && (primary == nil || connector.isActionPending))
    }

    private var line: some View {
        Rectangle().fill(WatchPalette.hairline).frame(height: 1)
    }

    private func fit(
        _ text: String,
        size: CGFloat,
        color: Color = WatchPalette.text,
        font: (CGFloat, Font.Weight) -> Font = monoFontName,
        alignment: TextAlignment = .trailing
    ) -> some View {
        Text(text)
            .font(font(size, .bold))
            .foregroundColor(color)
            .multilineTextAlignment(alignment)
            .watchAutoShrink(minScale: 0.4)
    }

    /// Ambient: the face dimmed to what matters, grey on black.
    private var ambient: some View {
        VStack(spacing: 2) {
            Text(card.stateLabel.uppercased())
                .font(monoFontName(size: 14))
            Text([card.exerciseName, card.setLine].filter { !$0.isEmpty }.joined(separator: " "))
                .font(textFontName(size: 14))
            Text(card.weightText == "?" ? "?" : "\(card.weightText) × \(card.repsText)")
                .font(monoFontName(size: 26))
        }
        .foregroundColor(WatchPalette.ambientText)
        .watchAutoShrink(minScale: 0.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
