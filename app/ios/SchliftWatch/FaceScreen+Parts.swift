import SwiftUI

/// The stage a face is drawn in: its name, its colour, the ink on it, its clock.
struct WatchStage {
    let label: String
    let color: Color
    let ink: Color
    let timer: String
}

/// The face's colours: the app's, or dimmed for always-on, where the same face is
/// drawn as grey lines and text on black with nothing filled.
struct FaceColors {
    let ground: Color
    let panel: Color
    let hairline: Color
    let rule: Color
    let text: Color
    let muted: Color
    let dim: Bool

    static let lit = FaceColors(
        ground: WatchPalette.ground, panel: WatchPalette.panel, hairline: WatchPalette.hairline,
        rule: WatchPalette.rule, text: WatchPalette.text, muted: WatchPalette.muted, dim: false
    )
    static let dimmed = FaceColors(
        ground: .black, panel: .black, hairline: WatchPalette.ambientLine,
        rule: WatchPalette.ambientLine, text: WatchPalette.ambientText, muted: WatchPalette.ambientText,
        dim: true
    )
}

/// The weight's press lights its whole panel orange, edge to edge.
struct PanelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? WatchPalette.lifting : Color.clear)
    }
}

/// How a set circle is drawn: the phone's SetCircle colours.
struct CircleLook {
    let fill: Color
    let ring: Color
    let ink: Color
}

func circleLook(_ state: Workout_V1_WearCircleState, stage: Color, colors: FaceColors) -> CircleLook {
    if colors.dim {
        // Dimmed, every circle is an outline: no lit discs.
        return CircleLook(fill: .clear, ring: colors.rule, ink: colors.text)
    }
    switch state {
    case .next:
        return CircleLook(fill: .clear, ring: stage, ink: stage)
    case .lifting:
        return CircleLook(fill: WatchPalette.lifting, ring: WatchPalette.lifting, ink: WatchPalette.text)
    case .full:
        return CircleLook(fill: WatchPalette.text, ring: WatchPalette.text, ink: WatchPalette.ground)
    case .short:
        return CircleLook(fill: WatchPalette.effort, ring: WatchPalette.effort, ink: WatchPalette.text)
    case .zero:
        return CircleLook(fill: .clear, ring: WatchPalette.effort, ink: WatchPalette.effort)
    case .skipped:
        return CircleLook(fill: .clear, ring: WatchPalette.hairline, ink: WatchPalette.muted)
    default:
        return CircleLook(fill: .clear, ring: WatchPalette.rule, ink: WatchPalette.muted)
    }
}

/// The stage the snapshot is in, at [nowMs].
func watchStage(_ snapshot: Workout_V1_WearWorkoutSnapshot, nowMs: Int64) -> WatchStage {
    let card = snapshot.youCard
    let onDark = WatchPalette.onDark
    switch snapshot.state {
    case .lifting:
        return WatchStage(
            label: card.stateLabel, color: WatchPalette.lifting, ink: onDark,
            timer: deriveLiftingTimer(snapshot, currentApiNowMs: nowMs)
        )
    case .resting, .yapping:
        let rest = deriveRestTimer(snapshot, currentApiNowMs: nowMs)
        if rest.restEnded {
            let label = card.yappingLabel.isEmpty ? card.stateLabel : card.yappingLabel
            return WatchStage(label: label, color: WatchPalette.yapping, ink: onDark, timer: rest.text)
        }
        return WatchStage(label: card.stateLabel, color: WatchPalette.resting, ink: onDark, timer: rest.text)
    default:
        return WatchStage(label: card.stateLabel, color: WatchPalette.ready, ink: onDark, timer: "")
    }
}

/// Rest on the dimmed face, in whole minutes: it is redrawn about once a minute, so
/// seconds would be wrong most of the time. `until` is when rest ends, which stays right
/// however late the redraw comes.
struct AmbientRest {
    let minutes: String
    let until: String
}

func ambientRestFor(_ snapshot: Workout_V1_WearWorkoutSnapshot, nowMs: Int64, now: Date) -> AmbientRest? {
    guard snapshot.state == .resting || snapshot.state == .yapping, snapshot.restUntil > 0 else { return nil }
    let words = snapshot.ambientCopy
    let minuteMs: Int64 = 60000
    let leftMs = snapshot.restUntil * 1000 - nowMs
    let minutes: String
    if leftMs > minuteMs {
        minutes = words.minLeft.replacingOccurrences(of: "{n}", with: "\((leftMs + minuteMs - 1) / minuteMs)")
    } else if leftMs > 0 {
        minutes = words.underAMin
    } else {
        let over = max(1, (-leftMs + minuteMs - 1) / minuteMs)
        minutes = words.minOver.replacingOccurrences(of: "{n}", with: "\(over)")
    }
    // restUntil is the phone's clock; the end as this watch's clock reads it.
    let endsAt = now.addingTimeInterval(TimeInterval(leftMs) / 1000)
    let time = endsAt.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    // Once rest is over its end is past: no "till".
    let until = leftMs > 0 ? words.restUntil.replacingOccurrences(of: "{time}", with: time) : ""
    return AmbientRest(minutes: minutes, until: until)
}

/// One end of the bar, loaded: the bar running in from the left for `lead`
/// (the screen's edge to the content), then the plates from the heaviest to
/// the lightest, then the sleeve's tip. Past four plates each is drawn
/// thinner, so a heavy bar leaves room for what is beside it.
func watchHalfBar(plates: [Workout_V1_WearPlate], height: CGFloat, lead: CGFloat) -> some View {
    let count = CGFloat(plates.count)
    let squeeze = count > 4 ? max(4 / count, 0.5) : 1
    let steel = height * 0.08
    return HStack(spacing: 1) {
        Rectangle().fill(WatchPalette.muted).frame(width: lead, height: steel)
        ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
            Rectangle()
                .fill(Color(hex: plate.colorHex))
                .frame(
                    width: height * (0.07 + 0.09 * CGFloat(plate.size)) * squeeze,
                    height: height * (0.45 + 0.55 * CGFloat(plate.size))
                )
        }
        Rectangle().fill(WatchPalette.muted).frame(width: height * 0.14, height: steel)
    }
}
