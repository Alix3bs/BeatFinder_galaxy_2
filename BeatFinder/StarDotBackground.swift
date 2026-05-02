import SwiftUI

struct StarDotBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<130 {
                    let xSeed = normalizedHash(Double(index) * 12.9898)
                    let ySeed = normalizedHash(Double(index) * 78.233)
                    let x = xSeed * size.width
                    let y = ySeed * size.height
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 0.9 + Double(index)))
                    let radius: CGFloat = index.isMultiple(of: 11) ? 1.8 : 0.8
                    let opacity = index.isMultiple(of: 11) ? 0.55 : 0.18

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(Color.white.opacity(opacity * twinkle))
                    )
                }

                for lineIndex in 0..<16 {
                    let y = CGFloat(lineIndex) / 16 * size.height
                    let opacity = 0.02 + 0.01 * (0.5 + 0.5 * sin(time * 0.35 + Double(lineIndex)))
                    context.stroke(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 0)),
                        with: .color(Color.white.opacity(opacity)),
                        lineWidth: 0.6
                    )
                }
            }
        }
        .background(Color.black)
    }

    private func normalizedHash(_ input: Double) -> CGFloat {
        CGFloat(abs(sin(input) * 43_758.5453).truncatingRemainder(dividingBy: 1))
    }
}
