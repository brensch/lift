import SwiftUI

/// The plates for the set's weight: the bar drawn loaded on white, the plates each
/// side and the bar's own weight. Shown in a sheet when the weight is tapped.
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
                Rectangle().fill(WatchPalette.hairline).frame(height: 1)
                bar(height: faceHeight * 0.26)
                    .frame(maxWidth: .infinity)
                    .frame(height: faceHeight * 0.30)
                    .background(Color.white)
                Rectangle().fill(WatchPalette.hairline).frame(height: 1)
                Text(card.platesText)
                    .font(monoFontName(size: faceHeight * 0.07))
                    .foregroundColor(WatchPalette.text)
                    .watchAutoShrink(minScale: 0.5)
                Text(card.barText)
                    .font(monoFontName(size: faceHeight * 0.06, weight: .regular))
                    .foregroundColor(WatchPalette.muted)
                    .watchAutoShrink()
                Spacer(minLength: 0)
            }
        }
        .background(WatchPalette.ground.ignoresSafeArea())
    }

    /// A barbell drawn loaded: plates out from the collars, sized by weight.
    private func bar(height: CGFloat) -> some View {
        HStack(spacing: 1) {
            Rectangle().fill(WatchPalette.hairline).frame(width: 10, height: 4)
            ForEach(Array(card.plates.reversed().enumerated()), id: \.offset) { _, plate in
                plateView(plate, height: height)
            }
            Rectangle().fill(WatchPalette.rule).frame(width: 4, height: 12)
            Rectangle().fill(WatchPalette.muted).frame(width: 30, height: 3)
            Rectangle().fill(WatchPalette.rule).frame(width: 4, height: 12)
            ForEach(Array(card.plates.enumerated()), id: \.offset) { _, plate in
                plateView(plate, height: height)
            }
            Rectangle().fill(WatchPalette.hairline).frame(width: 10, height: 4)
        }
    }

    private func plateView(_ plate: Workout_V1_WearPlate, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color(hex: plate.colorHex))
            .frame(width: 3 + 6 * CGFloat(plate.size), height: height * (0.32 + 0.68 * CGFloat(plate.size)))
    }
}
