import SwiftUI

/// The one status row every screen shares: elapsed time left, heart rate right in
/// its band colour. 16 pt grey. Hidden in ambient mode along with the countdown.
struct WatchStatusRow: View {
    let elapsedText: String
    let bpm: Double?

    var body: some View {
        HStack(spacing: 4) {
            Text(elapsedText)
                .font(textFontName(size: 16))
                .foregroundColor(WatchPalette.grey)
                .watchAutoShrink(minScale: 0.7)

            Spacer(minLength: 4)

            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundColor(heartRateColor(bpm))

            Text(formatBpm(bpm))
                .font(textFontName(size: 16))
                .foregroundColor(heartRateColor(bpm))
                .watchAutoShrink(minScale: 0.7)
        }
    }
}

/// The vertical, full-bleed, black frame shared by every workout screen: the status
/// row on top, the screen's own content under it. Keeping this in one place is what
/// makes the hierarchy identical across Ready, Rest and Done.
struct WatchScreen<Content: View>: View {
    @EnvironmentObject private var connector: PhoneConnector
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: Workout_V1_WearWorkoutSnapshot
    let now: Date
    let content: Content

    init(
        snapshot: Workout_V1_WearWorkoutSnapshot,
        now: Date,
        @ViewBuilder content: () -> Content
    ) {
        self.snapshot = snapshot
        self.now = now
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isLuminanceReduced {
                WatchStatusRow(
                    elapsedText: deriveElapsedText(snapshot, currentApiNowMs: watchNowMs(now)),
                    bpm: connector.latestBpm
                )
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

/// Unix milliseconds of the timeline tick being rendered. The watch's wall clock is
/// what the phone's absolute timestamps (`restUntil`, `workoutStartTime`) are
/// compared against; see `PhoneConnector.synchronizedNowMs`.
func watchNowMs(_ now: Date) -> Int64 {
    Int64(now.timeIntervalSince1970 * 1000)
}
