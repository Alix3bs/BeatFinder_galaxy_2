import SwiftUI

/// A more “real” looking spinning disc (Soundmap-ish)
struct RealisticDiscView: View {
    var size: CGFloat = 220
    var spinning: Bool = true
    var secondsPerRotation: Double = 6.0

    @State private var spin: Double = 0
    @State private var sheen: Double = 0

    var body: some View {
        ZStack {
            // Base “CD” material
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 1.00, green: 0.20, blue: 0.60), location: 0.00),
                            .init(color: Color(red: 1.00, green: 0.85, blue: 0.20), location: 0.18),
                            .init(color: Color(red: 0.20, green: 1.00, blue: 0.90), location: 0.42),
                            .init(color: Color(red: 0.45, green: 0.25, blue: 1.00), location: 0.66),
                            .init(color: Color(red: 1.00, green: 0.20, blue: 0.60), location: 1.00),
                        ]),
                        center: .center
                    )
                )

            // Dark rim (gives depth)
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: size * 0.06)
                .blur(radius: 1)
                .blendMode(.multiply)

            // Subtle groove rings
            GrooveRings()
                .clipShape(Circle())
                .opacity(0.22)

            // Specular “sheen” highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.00),
                            .white.opacity(0.28),
                            .white.opacity(0.00)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .rotationEffect(.degrees(sheen))

            // Inner hole
            Circle()
                .fill(Color.black.opacity(0.88))
                .frame(width: size * 0.22, height: size * 0.22)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.14), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(spin))
        // small tilt for “3D” feel
        .rotation3DEffect(.degrees(12), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 14)
        .onAppear {
            startSheen()
            startSpinIfNeeded()
        }
        .onChange(of: spinning) { _, _ in
            startSpinIfNeeded()
        }
    }

    private func startSheen() {
        sheen = 0
        withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
            sheen = 360
        }
    }

    private func startSpinIfNeeded() {
        guard spinning else { return }
        spin = 0
        withAnimation(.linear(duration: secondsPerRotation).repeatForever(autoreverses: false)) {
            spin = 360
        }
    }
}

/// Thin rings to mimic CD grooves
private struct GrooveRings: View {
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2
            // draw lots of faint rings
            for i in stride(from: maxR * 0.28, through: maxR * 0.96, by: 2.0) {
                var p = Path()
                p.addEllipse(in: CGRect(x: center.x - i, y: center.y - i, width: i * 2, height: i * 2))
                ctx.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 1)
            }
        }
    }
}
