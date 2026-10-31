import SwiftUI

/// ALL_DONE with a completion summary, in the split: the summary on the left, End
/// workout as the big half while the phone still offers it. Once it fires,
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
        GeometryReader { geo in
            let faceWidth = geo.size.width
            let faceHeight = geo.size.height
            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ALL DONE")
                        .font(monoFontName(size: faceHeight * 0.06))
                        .foregroundColor(WatchPalette.readyInk)
                    Text(summary.durationText)
                        .font(monoFontName(size: faceHeight * 0.13))
                        .foregroundColor(WatchPalette.text)
                    Text("\(summary.completedWorkingSets) sets")
                        .font(monoFontName(size: faceHeight * 0.068))
                        .foregroundColor(WatchPalette.muted)
                    Text(volumeText(summary))
                        .font(monoFontName(size: faceHeight * 0.068))
                        .foregroundColor(WatchPalette.muted)
                }
                .watchAutoShrink(minScale: 0.5)
                .padding(.trailing, 6)
                .frame(width: faceWidth * 0.57, alignment: .trailing)
                Rectangle().fill(WatchPalette.rule).frame(width: 1)
                Button {
                    if let end = endAction {
                        connector.sendIntent(action: end)
                    }
                } label: {
                    Text((endAction?.label ?? "").uppercased())
                        .font(monoFontName(size: faceHeight * 0.06))
                        .foregroundColor(WatchPalette.onDark)
                        .watchAutoShrink(lines: 2, minScale: 0.5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(endAction == nil ? WatchPalette.panel : WatchPalette.ready)
                }
                .buttonStyle(.plain)
                .disabled(endAction == nil || connector.isActionPending)
            }
        }
        .background(WatchPalette.ground.ignoresSafeArea())
    }

    /// The phone renders the volume in the user's unit; the lb figure is the fallback
    /// for a phone that has not sent `volumeText` yet.
    private func volumeText(_ summary: Workout_V1_WearCompletionSummary) -> String {
        summary.volumeText.isEmpty ? "\(summary.totalVolumeLb) lb" : summary.volumeText
    }
}
