import SwiftUI

private var uploadCard: some View {
    let boxSize: CGFloat = 340
    let discSize: CGFloat = 230
    let boxCorner: CGFloat = 22

    return ZStack {
        // BOX (artwork)
        Image("nest_music")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFill()
            .frame(width: boxSize, height: boxSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: boxCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: boxCorner, style: .continuous)
                    .fill(Color.black.opacity(0.25)) // keeps it readable but NOT blurry
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)

        // DISC on top (overlaps artwork)
        RealisticDiscView(size: discSize, spinning: true)
            .offset(y: -(discSize / 2)) // center of disc sits at top edge of box
            .zIndex(10)
    }
    .frame(width: boxSize, height: boxSize + discSize/2) // gives room for disc sticking out
}

