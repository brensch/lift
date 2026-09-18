import SwiftUI

// Custom fonts — registered via Info.plist UIAppFonts
let bodyFont = "Manrope-Variable"
private let displayFont = "SpaceGrotesk-Variable"

private func bodyFontName() -> Font {
    .custom(bodyFont, size: 14).weight(.medium)
}

func displayFontName(size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .custom(displayFont, size: size).weight(weight)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @EnvironmentObject var connector: PhoneConnector

    @State var selectedReps: Int = 0

    private var restBoundaryDate: Date? {
        guard let snapshot = connector.snapshot,
              snapshot.state == .resting,
              snapshot.restUntil > 0
        else {
            return nil
        }
        let restUntilMs = snapshot.restUntil * 1000
        let nowMs = connector.synchronizedNowMs()
        let deltaMs = restUntilMs - nowMs
        guard deltaMs > 0 else { return nil }
        return Date().addingTimeInterval(TimeInterval(deltaMs) / 1000.0)
    }

    var body: some View {
        TimelineView(WatchSchedule(restBoundary: restBoundaryDate, ambient: isLuminanceReduced)) { context in
            Group {
                if let snapshot = connector.snapshot {
                    workoutView(snapshot, now: context.date)
                } else {
                    VStack(spacing: 8) {
                        Text("Waiting for phone")
                            .foregroundColor(.white)
                            .watchAutoShrink()
                        // Build version of the WATCH app specifically. The watch app updates
                        // independently of the phone app, so this is the only reliable way to
                        // confirm the watch is actually running the latest code.
                        Text(watchAppVersionString())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
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
        .onChange(of: isLuminanceReduced) { reduced in
            if !reduced {
                connector.setUIVisible(true)
            }
        }
    }

    @ViewBuilder
    private func workoutView(_ data: Workout_V1_WearWorkoutSnapshot, now: Date) -> some View {
        let currentSet: Workout_V1_ProposedSet? = data.youCard.hasDisplaySet ? data.youCard.displaySet : nil
        let completeTemplate = data.actions.first { $0.type == .completeSet }
        let isLiftingCompleteMode = data.state == .lifting && currentSet != nil && completeTemplate != nil
        let primaryAction = data.actions.first { $0.style == .primary } ?? data.actions.first
        let completionSummary: Workout_V1_WearCompletionSummary? =
            data.hasCompletionSummary ? data.completionSummary : nil

        if data.state == .allDone, let summary = completionSummary {
            // Has the user already ended this workout from the watch? endedWorkoutID is set
            // (and @Published) the instant they tap, so this flips to the ended state
            // immediately — no waiting on the phone to echo a fresh snapshot back.
            let endedLocally = !connector.endedWorkoutID.isEmpty
                && connector.endedWorkoutID == data.workoutID
            // Offer "End Workout" only while the workout is genuinely still endable: all sets
            // done, not yet ended (an End action present), and not already ended from here.
            let canEnd = !endedLocally && primaryAction != nil

            workoutCompleteScreen(
                summary: summary,
                onPrimary: {
                    if canEnd, let action = primaryAction {
                        connector.sendIntent(action: action)
                    } else {
                        // Already ended — just make sure the local session is torn down.
                        connector.endLocalSession()
                    }
                },
                primaryLabel: canEnd ? (primaryAction?.label ?? "End Workout") : "Done"
            )
        } else {
            mainLayout(
                MainLayoutInput(
                    data: data,
                    now: now,
                    currentSet: currentSet,
                    completeTemplate: completeTemplate,
                    isLiftingCompleteMode: isLiftingCompleteMode,
                    primaryAction: primaryAction
                )
            )
        }
    }
}

extension View {
    func watchAutoShrink(lines: Int = 1, minScale: CGFloat = 0.5) -> some View {
        lineLimit(lines)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
    }
}

// MARK: - Helpers

private func watchAppVersionString() -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "watch v\(version) (\(build))"
}

/// Periodic schedule that also injects an explicit refresh tick at the rest-end
/// boundary so the color/state transition is visible even in ambient mode where
/// the periodic cadence drops to 60s.
struct WatchSchedule: TimelineSchedule {
    let restBoundary: Date?
    let ambient: Bool

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> AnyIterator<Date> {
        let interval: TimeInterval = ambient ? 60 : 1
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
}
