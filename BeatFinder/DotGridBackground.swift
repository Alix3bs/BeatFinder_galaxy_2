import SwiftUI

struct DotGridBackground: View {
    let dotColor: Color = Color.white.opacity(0.15)
    let spacing: CGFloat = 20
    let dotSize: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
    }
}
