import SwiftUI

/// The watch face, one layout for every live state: the phone's status box stacked for
/// the wrist, panels split by thin lines. From the top: the exercise's set circles, every
/// one tappable; the band (the stage, up next when it's you, its clock), its colour
/// draining off while you rest; the exercise and set; the weight (tap it for the plates)
/// × the reps in the set's circle; heart rate | workout length | the time.
struct FaceScreen: View {
    @EnvironmentObject private var connector: PhoneConnector
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    @State private var showPlates = false

    private var card: Workout_V1_WearStatusCard {
        snapshot.youCard
    }

    private var primary: Workout_V1_WearAction? {
        snapshot.actions.first { $0.type == .completeSet }
            ?? snapshot.actions.first { $0.type == .startSet }
    }

    /// The set in hand: the one being lifted, else the next.
    private var inHand: Workout_V1_WearSetCircle? {
        snapshot.circles.first { $0.state == .lifting }
            ?? snapshot.circles.first { $0.state == .next }
    }

    var body: some View {
        if isLuminanceReduced {
            ambient
        } else {
            Group {
                // Every frame while the rest drains the band, so it moves smoothly;
                // otherwise the screen's own one-second tick is enough.
                if restSpan != nil {
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

    // MARK: - The stage

    /// The rest being drained, in ms: from the end of the last set to restUntil.
    private var restSpan: ClosedRange<Int64>? {
        guard snapshot.state == .resting || snapshot.state == .yapping, snapshot.hasLastDone else { return nil }
        let start = snapshot.lastDone.endedAt * 1000
        let end = Int64(snapshot.restUntil) * 1000
        guard start > 0, end > start, watchNowMs(now) < end else { return nil }
        return start ... end
    }

    private func bandFill(nowMs: Int64) -> Double {
        guard let span = restSpan else { return 1 }
        let left = Double(span.upperBound - nowMs) / Double(span.upperBound - span.lowerBound)
        return min(max(left, 0), 1)
    }

    private var stage: WatchStage {
        watchStage(snapshot, nowMs: watchNowMs(now))
    }

    private func tapSet(_ setID: String) {
        connector.sendTap(setID: setID)
    }

    /// The rep circle taps the set in hand, or does the next thing there is to do.
    private func tapRep() {
        if let set = inHand {
            tapSet(set.setID)
        } else if let action = primary {
            connector.sendIntent(action: action)
        }
    }

    // MARK: - Layout

    private func face(nowMs: Int64) -> some View {
        let stage = stage
        let fill = bandFill(nowMs: nowMs)
        return GeometryReader { geo in
            let height = geo.size.height
            VStack(spacing: 0) {
                setRow(stage: stage, height: height * 0.19)
                line(WatchPalette.hairline)
                band(stage: stage, fill: fill, height: height * 0.20)
                line(WatchPalette.rule)
                exerciseRow(height: height * 0.11)
                line(WatchPalette.hairline)
                weightRow(stage: stage, height: height * 0.25)
                line(WatchPalette.hairline)
                stats(height: height * 0.13)
                line(WatchPalette.hairline)
                Spacer(minLength: 0)
            }
        }
        .background(WatchPalette.ground.ignoresSafeArea())
    }

    /// The exercise's sets, every one tappable, scrolled to the one in hand.
    private func setRow(stage: WatchStage, height: CGFloat) -> some View {
        let size = height * 0.66
        let current = inHand?.setID
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: size * 0.16) {
                    ForEach(snapshot.circles, id: \.setID) { circle in
                        setCircle(circle, stage: stage, size: circle.warmup ? size * 0.84 : size)
                            .id(circle.setID)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: height)
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
            .onChange(of: current) { setID in
                withAnimation { proxy.scrollTo(setID, anchor: .center) }
            }
        }
        .frame(height: height)
    }

    private func setCircle(_ circle: Workout_V1_WearSetCircle, stage: WatchStage, size: CGFloat) -> some View {
        let look = circleLook(circle.state, stage: stage.color)
        return Button {
            tapSet(circle.setID)
        } label: {
            Text(circle.text)
                .font(monoFontName(size: size * 0.45))
                .foregroundColor(look.ink)
                .watchAutoShrink(minScale: 0.5)
                .frame(width: size, height: size)
                .background(Circle().fill(look.fill))
                .overlay(Circle().strokeBorder(look.ring, lineWidth: circle.state == .next ? 2.5 : 1.5))
        }
        .buttonStyle(.plain)
        .disabled(connector.isActionPending)
    }

    /// The phone's status band: the stage, up next when it's you, its clock. While
    /// resting the stage colour drains off it, leaving it washed toward the panel.
    private func band(stage: WatchStage, fill: Double, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(stage.label.uppercased())
                .font(monoFontName(size: height * 0.32))
                .foregroundColor(stage.ink)
                .watchAutoShrink(minScale: 0.4)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !snapshot.upNextText.isEmpty {
                UpNextChip(text: snapshot.upNextText, size: height * 0.17)
                    .padding(.trailing, 4)
            }
            if !stage.timer.isEmpty {
                Text(stage.timer)
                    .font(monoFontName(size: height * 0.57))
                    .foregroundColor(stage.ink)
                    .watchAutoShrink(minScale: 0.4)
                    .layoutPriority(1)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: height)
        .background(
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(WatchPalette.panel)
                    Rectangle().fill(stage.color.opacity(fill < 1 ? 0.4 : 1))
                    Rectangle().fill(stage.color).frame(width: geo.size.width * fill)
                }
            }
        )
    }

    private var exerciseLine: String {
        [card.exerciseName, card.setLine].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func exerciseRow(height: CGFloat) -> some View {
        Text(exerciseLine)
            .font(textFontName(size: height * 0.44))
            .foregroundColor(WatchPalette.muted)
            .watchAutoShrink(minScale: 0.6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background(WatchPalette.panel)
    }

    private var weightText: String {
        card.weightText.isEmpty ? card.setText : card.weightText
    }

    /// The weight (tap it for the plates) × the reps, in the set's circle.
    private func weightRow(stage: WatchStage, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            Button {
                if !card.platesText.isEmpty {
                    showPlates = true
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(weightText)
                        .font(monoFontName(size: height * 0.61))
                        .watchAutoShrink(minScale: 0.4)
                    if weightText != "?" && !card.unitText.isEmpty {
                        Text(card.unitText).font(monoFontName(size: height * 0.21))
                    }
                }
                .foregroundColor(WatchPalette.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("×")
                .font(monoFontName(size: height * 0.28))
                .foregroundColor(WatchPalette.text)
            repCircle(stage: stage, size: height * 0.78)
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(WatchPalette.panel)
    }

    private func repCircle(stage: WatchStage, size: CGFloat) -> some View {
        let look = circleLook(inHand?.state ?? .pending, stage: stage.color)
        return Button {
            tapRep()
        } label: {
            Text(card.repsText)
                .font(monoFontName(size: size * 0.46))
                .foregroundColor(look.ink)
                .watchAutoShrink(minScale: 0.4)
                .frame(width: size * 0.86, height: size * 0.86)
                .background(Circle().fill(look.fill == .clear ? WatchPalette.panel : look.fill))
                .frame(width: size, height: size)
                .background(Circle().fill(look.ring))
        }
        .buttonStyle(.plain)
        .disabled(connector.isActionPending)
    }
}

extension FaceScreen {
    /// Heart rate | workout length | the time.
    private func stats(height: CGFloat) -> some View {
        let bpmColor = heartRateColor(connector.latestBpm)
        let size = height * 0.40
        return HStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.8))
                    .foregroundColor(bpmColor)
                statText(formatBpm(connector.latestBpm), size: size, color: bpmColor)
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(WatchPalette.hairline).frame(width: 1)
            statText(deriveElapsedText(snapshot, currentApiNowMs: watchNowMs(now)), size: size)
                .frame(maxWidth: .infinity)
            Rectangle().fill(WatchPalette.hairline).frame(width: 1)
            statText(now.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()), size: size)
                .frame(maxWidth: .infinity)
        }
        .frame(height: height)
    }

    private func statText(_ text: String, size: CGFloat, color: Color = WatchPalette.muted) -> some View {
        Text(text)
            .font(monoFontName(size: size))
            .foregroundColor(color)
            .watchAutoShrink(minScale: 0.5)
    }

    private func line(_ color: Color) -> some View {
        Rectangle().fill(color).frame(height: 1)
    }

    private var ambientRest: AmbientRest? {
        ambientRestFor(snapshot, nowMs: connector.synchronizedNowMs(), now: now)
    }

    /// Ambient: the face dimmed to what matters, grey on black: the stage, rest in
    /// minutes and when it ends, the exercise, the weight × reps.
    private var ambient: some View {
        VStack(spacing: 2) {
            Text(card.stateLabel.uppercased())
                .font(monoFontName(size: 14))
            if let rest = ambientRest {
                Text(rest.minutes)
                    .font(monoFontName(size: 34))
                if !rest.until.isEmpty {
                    Text(rest.until)
                        .font(monoFontName(size: 14))
                }
                Spacer().frame(height: 6)
            }
            Text(exerciseLine)
                .font(textFontName(size: 14))
            Text(weightText == "?" ? "?" : "\(weightText) × \(card.repsText)")
                .font(monoFontName(size: 26))
        }
        .foregroundColor(WatchPalette.ambientText)
        .watchAutoShrink(minScale: 0.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
