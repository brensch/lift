import SwiftUI

/// ALL_DONE with a completion summary: "Done" in green, the summary on one line, and
/// End workout while the phone still offers it. Once it fires,
/// `endLocalSession` records the workout as ended and `ContentView` returns to idle.
struct WorkoutDoneScreen: View {
    @EnvironmentObject private var connector: PhoneConnector

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    private var endAction: Workout_V1_WearAction? {
        snapshot.actions.first { $0.type == .endWorkout }
    }

    var body: some View {
        let summary = snapshot.completionSummary

        WatchScreen(snapshot: snapshot, now: now) {
            VStack(spacing: 2) {
                Spacer(minLength: 0)

                Text("Done")
                    .font(displayFontName(size: 26))
                    .foregroundColor(WatchPalette.doneGreen)
                    .watchAutoShrink()

                Text("\(summary.durationText) · \(summary.completedWorkingSets) sets · \(volumeText(summary))")
                    .font(textFontName(size: 14))
                    .foregroundColor(WatchPalette.grey)
                    .watchAutoShrink(minScale: 0.6)

                Spacer(minLength: 4)

                if let end = endAction {
                    WatchPrimaryButton(label: end.label, height: 48, enabled: !connector.isActionPending) {
                        connector.sendIntent(action: end)
                    }
                }
            }
        }
    }

    /// The phone renders the volume in the user's unit; the lb figure is the fallback
    /// for a phone that has not sent `volumeText` yet.
    private func volumeText(_ summary: Workout_V1_WearCompletionSummary) -> String {
        summary.volumeText.isEmpty ? "\(summary.totalVolumeLb)lb" : summary.volumeText
    }
}
