import SwiftUI

/// The one primary action: full-width white, black 20 bold text, 56 tall by default.
/// Start on Ready and Rest (48 tall), Done on Lifting, End workout on Done.
struct WatchPrimaryButton: View {
    let label: String
    var height: CGFloat = 56
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(displayFontName(size: 20))
                .foregroundColor(.black)
                .watchAutoShrink(minScale: 0.6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

/// A rung's finishes (reps left: 0–1, 2–3, 4+) from the snapshot's COMPLETE_SET
/// actions: white like the primary, side by side. Each logs the rung and answers for it.
struct WatchFinishRow: View {
    @EnvironmentObject private var connector: PhoneConnector

    let finishes: [Workout_V1_WearAction]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(finishes, id: \.effort) { action in
                Button {
                    connector.sendIntent(action: action)
                } label: {
                    Text(action.label)
                        .font(displayFontName(size: 15))
                        .foregroundColor(.black)
                        .watchAutoShrink(minScale: 0.6)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(connector.isActionPending)
                .opacity(connector.isActionPending ? 0.5 : 1)
            }
        }
    }
}
