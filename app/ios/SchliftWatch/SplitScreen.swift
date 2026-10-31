import SwiftUI

/// The stage a face is drawn in: its name, its colours, its clock.
struct WatchStage {
    let label: String
    let ink: Color
    let color: Color
    let onColor: Color
    let timer: String
}

/// The watch face, one layout for every live state (the "split"): information rows
/// on the left, split by thin lines (the clock, heart rate and workout length, the
/// exercise and set, the weight, the time and who's up next); the right is one big
/// button in the stage's colour with the reps on it and the stage's name. Tap the
/// weight for the plates. For a few seconds after a set ends the button turns amber
/// and each tap takes a rep off it, a bar draining down its edge.
struct SplitScreen: View {
    @EnvironmentObject private var connector: PhoneConnector
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    @State private var showPlates = false
    @State private var fixSetID = ""
    @State private var fixReps: Int32 = 0
    @State private var lastFixTapMs: Int64 = 0

    private var card: Workout_V1_WearStatusCard {
        snapshot.youCard
    }

    private var primary: Workout_V1_WearAction? {
        snapshot.actions.first { $0.type == .completeSet }
            ?? snapshot.actions.first { $0.type == .startSet }
    }

    var body: some View {
        if isLuminanceReduced {
            ambient
        } else {
            Group {
                // Every frame while the fix window runs, so its bar drains smoothly;
                // otherwise the screen's own one-second tick is enough.
                if fixWindowEndMs > watchNowMs(now) {
                    TimelineView(.animation) { _ in
                        face(nowMs: connector.synchronizedNowMs())
                    }
                } else {
                    face(nowMs: connector.synchronizedNowMs())
                }
            }
            // The system sheet: slides over the face, closes with its own button.
            .sheet(isPresented: $showPlates) {
                PlateScreen(card: card)
            }
        }
    }

    // MARK: - The fix window

    private var fixWindowEndMs: Int64 {
        guard snapshot.hasLastDone else { return 0 }
        return max(snapshot.lastDone.endedAt * 1000, lastFixTapMs) + 3000
    }

    private func inFixWindow(nowMs: Int64) -> Bool {
        snapshot.hasLastDone && snapshot.state != .lifting && nowMs < fixWindowEndMs
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

    // MARK: - The stage

    private var stage: WatchStage {
        let nowMs = watchNowMs(now)
        let rest = deriveRestTimer(snapshot, currentApiNowMs: nowMs)
        if card.firstTime {
            return WatchStage(
                label: card.stateLabel, ink: WatchPalette.liftingInk,
                color: WatchPalette.firstTime, onColor: WatchPalette.onDark, timer: ""
            )
        }
        switch snapshot.state {
        case .lifting:
            return WatchStage(
                label: card.stateLabel, ink: WatchPalette.liftingInk, color: WatchPalette.lifting,
                onColor: WatchPalette.text, timer: deriveLiftingTimer(snapshot, currentApiNowMs: nowMs)
            )
        case .resting, .yapping:
            if rest.restEnded {
                let label = card.yappingLabel.isEmpty ? card.stateLabel : card.yappingLabel
                return WatchStage(
                    label: label, ink: WatchPalette.yappingInk, color: WatchPalette.yapping,
                    onColor: WatchPalette.onDark, timer: rest.text
                )
            }
            return WatchStage(
                label: card.stateLabel, ink: WatchPalette.resting, color: WatchPalette.resting,
                onColor: WatchPalette.onDark, timer: rest.text
            )
        default:
            return WatchStage(
                label: card.stateLabel, ink: WatchPalette.readyInk, color: WatchPalette.ready,
                onColor: WatchPalette.onDark, timer: ""
            )
        }
    }

    // MARK: - Layout

    private func face(nowMs: Int64) -> some View {
        let stage = stage
        let fixing = inFixWindow(nowMs: nowMs)
        let windowLeft = fixing ? Double(fixWindowEndMs - nowMs) / 3000 : 0
        return GeometryReader { geo in
            let faceHeight = geo.size.height
            HStack(spacing: 0) {
                left(stage: stage, faceHeight: faceHeight)
                    .frame(width: geo.size.width * 0.57)
                Rectangle().fill(WatchPalette.rule).frame(width: 1)
                bigButton(stage: stage, fixing: fixing, windowLeft: windowLeft, faceHeight: faceHeight, nowMs: nowMs)
            }
        }
        .background(WatchPalette.ground.ignoresSafeArea())
    }

    private func left(stage: WatchStage, faceHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            // The clock, as big as fits: the stage is named on the button.
            VStack(alignment: .trailing, spacing: 0) {
                Spacer(minLength: 0)
                fit(stage.timer.isEmpty ? "—" : stage.timer, size: faceHeight * 0.20, color: stage.ink)
            }
            .padding(.trailing, 6)
            .frame(height: faceHeight * 0.34)
            line
            stats(faceHeight: faceHeight)
            line
            fit(exerciseLine, size: faceHeight * 0.058, font: textFontName)
                .padding(.trailing, 6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: faceHeight * 0.09)
                .background(WatchPalette.panel)
            line
            weight(faceHeight: faceHeight)
            line
            VStack(alignment: .trailing, spacing: 0) {
                fit(
                    now.formatted(date: .omitted, time: .shortened),
                    size: faceHeight * 0.055,
                    color: WatchPalette.muted
                )
                if !snapshot.nextUpEmoji.isEmpty {
                    fit("next \(snapshot.nextUpEmoji)", size: faceHeight * 0.052, color: WatchPalette.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
            .padding(.trailing, 6)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var exerciseLine: String {
        [card.exerciseName, card.setLine].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Heart rate | workout length.
    private func stats(faceHeight: CGFloat) -> some View {
        let bpmColor = heartRateColor(connector.latestBpm)
        return HStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: faceHeight * 0.05))
                    .foregroundColor(bpmColor)
                fit(formatBpm(connector.latestBpm), size: faceHeight * 0.068, color: bpmColor)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 4)
            Rectangle().fill(WatchPalette.hairline).frame(width: 1)
            fit(deriveElapsedText(snapshot, currentApiNowMs: watchNowMs(now)), size: faceHeight * 0.068)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 6)
        }
        .frame(height: faceHeight * 0.10)
        .background(WatchPalette.panel)
    }

    /// The weight; tap it for the plates.
    private func weight(faceHeight: CGFloat) -> some View {
        Button {
            if !card.platesText.isEmpty {
                showPlates = true
            }
        } label: {
            fit(card.weightText == "?" ? "?" : "\(card.weightText) \(card.unitText)", size: faceHeight * 0.13)
                .padding(.trailing, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .frame(height: faceHeight * 0.14)
        .background(WatchPalette.panel)
    }

    private func bigButton(
        stage: WatchStage,
        fixing: Bool,
        windowLeft: Double,
        faceHeight: CGFloat,
        nowMs: Int64
    ) -> some View {
        let color = fixing ? WatchPalette.fix : stage.color
        let ink = fixing ? WatchPalette.text : stage.onColor
        let reps = fixing ? "\(shownFixReps)" : card.repsText
        let cue = (fixing ? snapshot.lastDone.cue : stage.label).uppercased()
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
                    fit(reps, size: faceHeight * 0.30, color: ink, alignment: .center)
                    fit(cue, size: faceHeight * 0.055, color: ink, alignment: .center)
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
            Text(exerciseLine)
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
