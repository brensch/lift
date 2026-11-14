import SwiftUI

/// The plates for the set's weight, as the phone's edit sheet has them: the
/// end of the bar drawn loaded on white, the bar coming in from the screen's
/// edge, and beside it each plate size on a row of its own with how many
/// ("45×3"). Shown in a sheet when the weight is tapped.
struct PlateScreen: View {
    let card: Workout_V1_WearStatusCard

    var body: some View {
        GeometryReader { geo in
            let faceHeight = geo.size.height
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Text("\(card.weightText) \(card.unitText)")
                    .font(monoFontName(size: faceHeight * 0.14))
                    .foregroundColor(WatchPalette.text)
                    .watchAutoShrink()
                // The white runs right up to the lines either side of it.
                VStack(spacing: 0) {
                    Rectangle().fill(WatchPalette.hairline).frame(height: 1)
                    HStack(spacing: 0) {
                        watchHalfBar(plates: card.plates, height: faceHeight * 0.34, lead: 12)
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(plateCounts.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(monoFontName(size: faceHeight * 0.075))
                                    .foregroundColor(WatchPalette.text)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.trailing, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: faceHeight * 0.44)
                    .background(Color.white)
                    Rectangle().fill(WatchPalette.hairline).frame(height: 1)
                }
                Spacer(minLength: 0)
            }
        }
        // The lines and the white run to the screen's sides.
        .ignoresSafeArea(edges: .horizontal)
        .background(WatchPalette.ground.ignoresSafeArea())
    }

    /// Each plate size once, heaviest first; one loaded more than once says
    /// how many: "45×3", "10", "5".
    private var plateCounts: [String] {
        var lines: [String] = []
        var index = 0
        while index < card.plates.count {
            var count = 1
            while index + count < card.plates.count,
                  card.plates[index + count].label == card.plates[index].label
            {
                count += 1
            }
            let label = card.plates[index].label
            lines.append(count > 1 ? "\(label)×\(count)" : label)
            index += count
        }
        return lines
    }
}
