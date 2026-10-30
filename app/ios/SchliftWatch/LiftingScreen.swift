import SwiftUI

/// LIFTING: the set in progress. An orange count-up from Start, the set, and its
/// finishes: one Done, or for a finding-weight rung how many reps were left (0–1 /
/// 2–3 / 4+), each logging the rung and answering for it in one tap.
struct LiftingScreen: View {
    @EnvironmentObject private var connector: PhoneConnector
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    /// The finishes, in the order the phone sent them.
    private var finishes: [Workout_V1_WearAction] {
        snapshot.actions.filter { $0.type == .completeSet }
    }

    var body: some View {
        let card = snapshot.youCard
        let timerText = deriveLiftingTimer(snapshot, currentApiNowMs: watchNowMs(now))

        WatchScreen(snapshot: snapshot, now: now) {
            VStack(spacing: 2) {
                Spacer(minLength: 0)

                if !isLuminanceReduced {
                    Text(timerText)
                        .font(displayFontName(size: 40))
                        .foregroundColor(WatchPalette.liftingOrange)
                        .watchAutoShrink()
                }

                Text(card.stateLabel)
                    .font(textFontName(size: 14))
                    .foregroundColor(WatchPalette.liftingOrange)
                    .watchAutoShrink(minScale: 0.7)

                Text("\(card.exerciseName) \(card.setText)")
                    .font(textFontName(size: 14))
                    .foregroundColor(.white)
                    .watchAutoShrink(minScale: 0.6)

                Spacer(minLength: 4)

                if finishes.count == 1, let done = finishes.first {
                    WatchPrimaryButton(label: done.label, height: 48, enabled: !connector.isActionPending) {
                        connector.sendIntent(action: done)
                    }
                } else if !finishes.isEmpty {
                    WatchFinishRow(finishes: finishes)
                }
            }
        }
    }
}
