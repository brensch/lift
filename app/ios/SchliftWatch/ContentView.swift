import SwiftUI

/// The phone app's fonts, registered via Info.plist UIAppFonts: Space Grotesk for
/// words, Space Mono for numbers.
private let bodyFont = "SpaceGrotesk-Variable"

func textFontName(size: CGFloat, weight: Font.Weight = .medium) -> Font {
    .custom(bodyFont, size: size).weight(weight)
}

func monoFontName(size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .custom(weight == .regular ? "SpaceMono-Regular" : "SpaceMono-Bold", size: size)
}

/// Routes the phone's snapshot to one of the screens. The phone is authoritative:
/// every string is laid out as sent and every tap is an intent back to it.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @EnvironmentObject var connector: PhoneConnector

    /// When rest ends (or ended), on this watch's clock.
    private var restBoundaryDate: Date? {
        guard let snapshot = connector.snapshot,
              snapshot.state == .resting || snapshot.state == .yapping,
              snapshot.restUntil > 0
        else {
            return nil
        }
        let restUntilMs = snapshot.restUntil * 1000
        let deltaMs = restUntilMs - connector.synchronizedNowMs()
        return Date().addingTimeInterval(TimeInterval(deltaMs) / 1000.0)
    }

    var body: some View {
        TimelineView(WatchSchedule(restBoundary: restBoundaryDate, ambient: isLuminanceReduced)) { context in
            Group {
                if let snapshot = connector.snapshot, !endedLocally(snapshot) {
                    workoutView(snapshot, now: context.date)
                } else {
                    IdleScreen()
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
        .onChange(of: isLuminanceReduced) { reduced in
            if !reduced {
                connector.setUIVisible(true)
            }
        }
    }

    /// Ended from the watch (End workout tapped) or by the phone's dedicated end command:
    /// `endLocalSession` records the id the instant it happens, so the watch returns to
    /// idle without waiting for the phone to echo a fresh snapshot.
    private func endedLocally(_ snapshot: Workout_V1_WearWorkoutSnapshot) -> Bool {
        !connector.endedWorkoutID.isEmpty && connector.endedWorkoutID == snapshot.workoutID
    }

    @ViewBuilder
    private func workoutView(_ snapshot: Workout_V1_WearWorkoutSnapshot, now: Date) -> some View {
        // One face for every live state, and Done at the end.
        switch snapshot.state {
        case .allDone where snapshot.hasCompletionSummary:
            WorkoutDoneScreen(snapshot: snapshot, now: now)
        default:
            FaceScreen(snapshot: snapshot, now: now)
        }
    }
}

/// No snapshot: the phone has no workout running, or has not reached us yet.
struct IdleScreen: View {
    var body: some View {
        Text("Open Schlift on your phone")
            .font(textFontName(size: 15))
            .foregroundColor(WatchPalette.muted)
            .watchAutoShrink(lines: 2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WatchPalette.ground.ignoresSafeArea())
    }
}

extension View {
    func watchAutoShrink(lines: Int = 1, minScale: CGFloat = 0.5) -> some View {
        lineLimit(lines)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
    }
}

/// Periodic schedule that also injects an explicit refresh tick at the rest-end
/// boundary so the color/state transition is visible even in ambient mode where
/// the periodic cadence drops to 60s.
struct WatchSchedule: TimelineSchedule {
    let restBoundary: Date?
    let ambient: Bool

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> AnyIterator<Date> {
        if ambient {
            return ambientEntries(from: startDate)
        }
        let interval: TimeInterval = 1
        var cursor = startDate
        var boundaryEmitted = false
        let boundary = restBoundary
        return AnyIterator {
            // If a future boundary falls before the next periodic tick, emit it once.
            if let boundary = boundary,
               !boundaryEmitted,
               boundary > cursor,
               boundary <= cursor.addingTimeInterval(interval)
            {
                boundaryEmitted = true
                let entry = boundary
                cursor = boundary.addingTimeInterval(interval)
                return entry
            }
            let entry = cursor
            cursor = cursor.addingTimeInterval(interval)
            return entry
        }
    }

    /// Dimmed, the face is redrawn about once a minute: on each whole minute of rest (so
    /// its minute count turns over on time) and on the clock's minute (the face shows the
    /// time), whichever comes next. A moment past the turn, so the count has changed.
    private func ambientEntries(from startDate: Date) -> AnyIterator<Date> {
        let clock = Date(timeIntervalSinceReferenceDate: 0)
        var restTick = restBoundary.map { Self.nextTurn(of: $0, after: startDate) }
        var clockTick = Self.nextTurn(of: clock, after: startDate)
        var first = true
        return AnyIterator {
            if first {
                first = false
                return startDate
            }
            if let rest = restTick, rest < clockTick {
                restTick = rest.addingTimeInterval(60)
                return rest
            }
            let entry = clockTick
            clockTick = clockTick.addingTimeInterval(60)
            return entry
        }
    }

    /// The first whole minute from [anchor] after [date], plus a moment.
    private static func nextTurn(of anchor: Date, after date: Date) -> Date {
        let phase = anchor.timeIntervalSince(date).truncatingRemainder(dividingBy: 60)
        return date.addingTimeInterval((phase <= 0 ? phase + 60 : phase) + 0.3)
    }
}
