import SwiftUI

/// The stage a face is drawn in: its name, its colour, the ink on it, its clock.
struct WatchStage {
    let label: String
    let color: Color
    let ink: Color
    let timer: String
}

/// How a set circle is drawn: the phone's SetCircle colours.
struct CircleLook {
    let fill: Color
    let ring: Color
    let ink: Color
}

func circleLook(_ state: Workout_V1_WearCircleState, stage: Color) -> CircleLook {
    switch state {
    case .next:
        return CircleLook(fill: .clear, ring: stage, ink: stage)
    case .lifting:
        return CircleLook(fill: WatchPalette.lifting, ring: WatchPalette.lifting, ink: WatchPalette.text)
    case .full:
        return CircleLook(fill: WatchPalette.text, ring: WatchPalette.text, ink: WatchPalette.ground)
    case .short:
        return CircleLook(fill: WatchPalette.fix, ring: WatchPalette.fix, ink: WatchPalette.text)
    case .zero:
        return CircleLook(fill: .clear, ring: WatchPalette.fix, ink: WatchPalette.fix)
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
    if card.firstTime {
        return WatchStage(label: card.stateLabel, color: WatchPalette.firstTime, ink: onDark, timer: "")
    }
    switch snapshot.state {
    case .lifting:
        return WatchStage(
            label: card.stateLabel, color: WatchPalette.lifting, ink: WatchPalette.text,
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

/// "Up next!" on the panel, its ink gliding through the app's series palette.
struct UpNextChip: View {
    let text: String
    let size: CGFloat

    private static let colors = [
        Color(rgb: 0x1F4FD1), Color(rgb: 0xD03A00), Color(rgb: 0x1E7A3C), Color(rgb: 0xC2185B),
        Color(rgb: 0x5B2DB8), Color(rgb: 0x00796B), Color(rgb: 0x8D5A00),
    ]

    var body: some View {
        TimelineView(.animation) { context in
            // Each colour for 0.7 s; the ink fades from one to the next.
            let step = context.date.timeIntervalSinceReferenceDate / 0.7
            let index = Int(step) % Self.colors.count
            let blend = step - step.rounded(.down)
            ZStack {
                Text(text).foregroundColor(Self.colors[index])
                Text(text)
                    .foregroundColor(Self.colors[(index + 1) % Self.colors.count])
                    .opacity(blend)
            }
            .font(monoFontName(size: size))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize()
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(WatchPalette.panel)
        }
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
