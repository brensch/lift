import SwiftUI

extension ContentView {
    func workoutCompleteScreen(
        summary: Workout_V1_WearCompletionSummary,
        onPrimary: (() -> Void)?,
        primaryLabel: String
    ) -> some View {
        // Match Android's WorkoutCompleteScreen: stats take 2/3, the white action button
        // takes a fixed 1/3. We size the two columns explicitly via GeometryReader because
        // SwiftUI's layoutPriority is NOT proportional — it let the stats column eat the full
        // width and collapsed the button column to ~0pt (the "missing End workout button").
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Complete")
                        .font(displayFontName(size: 26))
                        .foregroundColor(.white)
                        .watchAutoShrink()
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Spacer().frame(height: 6)

                    completionMetric(label: "Time", value: summary.durationText)
                    completionMetric(label: "Sets", value: "\(summary.completedWorkingSets)")
                    completionMetric(label: "Vol", value: "\(summary.totalVolumeLb)lb")

                    // Diagnostic: live HK session state — should go to "ended" after End and
                    // stay there (no flicker back to "running").
                    Text("hk: \(connector.sessionStateLabel)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 6))
                .frame(width: geo.size.width * 2.0 / 3.0, height: geo.size.height)

                Button {
                    onPrimary?()
                } label: {
                    Text(primaryLabel)
                        .font(displayFontName(size: 16))
                        .foregroundColor(.black)
                        .watchAutoShrink(lines: 2)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .frame(width: geo.size.width / 3.0, height: geo.size.height)
                .background(Color.white)
                .disabled(onPrimary == nil)
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    private func completionMetric(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(bodyFont, size: 13))
                .foregroundColor(Color(red: 0x9C / 255, green: 0xA3 / 255, blue: 0xAF / 255))
                .watchAutoShrink(minScale: 0.7)

            Spacer()

            Text(value)
                .font(displayFontName(size: 18))
                .foregroundColor(.white)
                .watchAutoShrink()
        }
        .padding(.vertical, 1)
    }
}
