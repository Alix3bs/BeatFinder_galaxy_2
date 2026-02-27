import SwiftUI

struct SoundmapDiscView: View {
    var spinning: Bool = true
    var size: CGFloat = 200
    var duration: Double = 6.0  // seconds per full rotation (like RN example)

    @State private var rotation: Double = 0
    @State private var spinToken = UUID() // forces animation restart cleanly

    var body: some View {
        ZStack {
            // Outer disc (conic/rainbow feel)
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 0.48),  // #ff007a
                            Color(red: 1.0, green: 0.90, blue: 0.0),  // #ffe600
                            Color(red: 0.0, green: 1.0, blue: 0.92),  // #00ffea
                            Color(red: 0.48, green: 0.0, blue: 1.0),  // #7a00ff
                            Color(red: 1.0, green: 0.0, blue: 0.48)   // repeat start
                        ]),
                        center: .center
                    )
                )
                .overlay(
                    // subtle highlight ring
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 2)
                        .padding(2)
                )
                .overlay(
                    // optional "groove" rings (very subtle)
                    ZStack {
                        ForEach(0..<5) { i in
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                .padding(CGFloat(18 + i * 12))
                        }
                    }
                )
                .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 10)

            // Inner hole
            Circle()
                .fill(Color(white: 0.07))
                .frame(width: size * 0.22, height: size * 0.22)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.20), lineWidth: 3)
                )
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .id(spinToken)
        .onAppear { applySpinState() }
        .onChange(of: spinning) { _, _ in
            applySpinState()
        }
    }

    private func applySpinState() {
        if spinning {
            rotation = 0
            spinToken = UUID() // restart animation cleanly
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            // Stop: freeze at current rotation (no animation)
            withAnimation(.none) { rotation = rotation.truncatingRemainder(dividingBy: 360) }
        }
    }
}
