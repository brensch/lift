import SwiftUI

/// READY: the next set is the whole screen. Exercise name, "<weight> × <reps>" as the
/// biggest thing, the set line, then Start.
struct ReadyScreen: View {
    @EnvironmentObject private var connector: PhoneConnector

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date

    private var startAction: Workout_V1_WearAction? {
        snapshot.actions.first { $0.type == .startSet }
    }

    var body: some View {
        let card = snapshot.youCard

        WatchScreen(snapshot: snapshot, now: now) {
            VStack(spacing: 2) {
                Spacer(minLength: 0)

                Text(card.exerciseName)
                    .font(displayFontName(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .watchAutoShrink(minScale: 0.6)

                Text(card.setText)
                    .font(displayFontName(size: 34))
                    .foregroundColor(.white)
                    .watchAutoShrink()

                Text(card.setLine)
                    .font(textFontName(size: 14))
                    .foregroundColor(WatchPalette.grey)
                    .watchAutoShrink(minScale: 0.7)

                Spacer(minLength: 6)

                if let start = startAction {
                    WatchPrimaryButton(label: start.label, enabled: !connector.isActionPending) {
                        connector.sendIntent(action: start)
                    }
                }
            }
        }
    }
}
