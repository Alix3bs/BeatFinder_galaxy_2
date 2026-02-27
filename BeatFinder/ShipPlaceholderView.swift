import SwiftUI

/// SwiftUI placeholder for the Style C spaceship design.
/// This can be used as a reference or converted to SpriteKit for the mini-game.
struct ShipPlaceholderView: View {
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 70, height: 70)
                .blur(radius: 12)

            // Body
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black)
                .frame(width: 50, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.cyan, .blue, .purple, .pink, .cyan]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                )
                .rotationEffect(.degrees(0)) // pointing up

            // Cockpit
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 16, height: 16)
                .shadow(color: .cyan.opacity(0.8), radius: 8)

            // Engines (bottom)
            VStack(spacing: 4) {
                Spacer().frame(height: 40)

                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 6, height: 6)
                        .shadow(color: .cyan.opacity(0.9), radius: 6)

                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 6, height: 6)
                        .shadow(color: .cyan.opacity(0.9), radius: 6)
                }
            }
        }
        .frame(width: 80, height: 100)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ShipPlaceholderView()
    }
}
