import ActivityKit
import SwiftUI
import WidgetKit

/// The widget extension: it draws the live status (`LiveStatusAttributes`)
/// on the lock screen and in the Dynamic Island. It holds no state of its
/// own; the app starts and updates the activity (`LiveStatusPlugin`).
@main
struct LiveStatusBundle: WidgetBundle {
    var body: some Widget {
        LiveStatusWidget()
    }
}

struct LiveStatusWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveStatusAttributes.self) { context in
            LockScreenStatus(phase: context.phase)
                .activityBackgroundTint(context.phase.fill)
                .activitySystemActionForegroundColor(context.phase.inkColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.phase.stage)
                        .font(.title3.weight(.bold))
                        .foregroundColor(context.phase.fill)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PhaseClock(phase: context.phase)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SetInHand(phase: context.phase)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                // "Rest" then its countdown, either side of the camera.
                Text(context.phase.short)
                    .font(.caption.weight(.bold))
                    .foregroundColor(context.phase.fill)
            } compactTrailing: {
                PhaseClock(phase: context.phase)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 48)
            } minimal: {
                // Sharing the island with another app: the clock alone, or
                // the stage's colour when it has none.
                if context.phase.clock == nil {
                    Circle().fill(context.phase.fill).padding(4)
                } else {
                    PhaseClock(phase: context.phase)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundColor(context.phase.fill)
                        .minimumScaleFactor(0.6)
                }
            }
            .keylineTint(context.phase.fill)
        }
    }
}

/// The lock screen's card: the stage and its clock on the stage's colour,
/// the set in hand under them. The app's status box, lying down.
struct LockScreenStatus: View {
    let phase: LiveStatusAttributes.Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(phase.stage)
                    .font(.title2.weight(.bold))
                Spacer(minLength: 12)
                PhaseClock(phase: phase)
                    .font(.title.weight(.bold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
            SetInHand(phase: phase)
        }
        .foregroundColor(phase.inkColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// "Squat" over "100 kg × 5 · Set 2 of 5".
struct SetInHand: View {
    let phase: LiveStatusAttributes.Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phase.exercise)
                .font(.headline)
                .lineLimit(1)
            Text(phase.detail)
                .font(.subheadline.monospacedDigit())
                .lineLimit(1)
                .opacity(0.8)
        }
    }
}

/// The stage's clock, ticking by itself: down to the rest's end, or up
/// from the moment the stage began. Nothing when the stage has no clock.
struct PhaseClock: View {
    let phase: LiveStatusAttributes.Phase

    var body: some View {
        if let clock = phase.clock {
            if phase.countDown {
                Text(timerInterval: min(Date(), clock) ... clock, countsDown: true)
            } else {
                Text(clock, style: .timer)
            }
        }
    }
}

extension ActivityViewContext where Attributes == LiveStatusAttributes {
    /// What to draw: once the activity is stale (the rest ran out), what
    /// was to come then.
    var phase: LiveStatusAttributes.Phase {
        isStale ? state.then ?? state.now : state.now
    }
}

extension LiveStatusAttributes.Phase {
    var fill: Color {
        Color(argb: color)
    }

    var inkColor: Color {
        Color(argb: ink)
    }
}

extension Color {
    /// A colour from 0xAARRGGBB, as the app's theme writes them.
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
