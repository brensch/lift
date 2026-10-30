import SwiftUI

/// The screen after each set: RESTING, then YAPPING once the rest has run out. The
/// timer says what to do: a blue countdown to `restUntil`, then a pink count-up from
/// it. Under it the next set and Start, which lifts it, early or late.
struct RestScreen: View {
    @EnvironmentObject private var connector: PhoneConnector
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    private var startAction: Workout_V1_WearAction? {
        snapshot.actions.first { $0.type == .startSet }
    }

    var body: some View {
        let card = snapshot.youCard
        let timer = deriveRestTimer(snapshot, currentApiNowMs: watchNowMs(now))
        let colour = timer.restEnded ? WatchPalette.yappingPink : WatchPalette.restingBlue
        // Each watch flips the labels itself when the countdown reaches zero; the
        // phone sends both so the watch never writes copy.
        let stateLabel = timer.restEnded ? orFallback(card.yappingLabel, card.stateLabel) : card.stateLabel

        WatchScreen(snapshot: snapshot, now: now) {
            VStack(spacing: 2) {
                Spacer(minLength: 0)

                if !isLuminanceReduced {
                    Text(timer.text)
                        .font(displayFontName(size: 40))
                        .foregroundColor(colour)
                        .watchAutoShrink()
                }

                Text(stateLabel)
                    .font(textFontName(size: 14))
                    .foregroundColor(colour)
                    .watchAutoShrink(minScale: 0.7)

                Text("Next: \(card.setText)")
                    .font(textFontName(size: 14))
                    .foregroundColor(.white)
                    .watchAutoShrink(minScale: 0.6)

                Spacer(minLength: 4)

                if let start = startAction {
                    WatchPrimaryButton(label: start.label, height: 48, enabled: !connector.isActionPending) {
                        connector.sendIntent(action: start)
                    }
                }
            }
        }
    }

    private func orFallback(_ text: String, _ fallback: String) -> String {
        text.isEmpty ? fallback : text
    }
}
