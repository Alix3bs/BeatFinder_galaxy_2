import SwiftUI

struct AnimatedGalaxyBackground: View {
    @State private var shift = false

    var body: some View {
        ZStack {
            AngularGradient(
                colors: [
                    .purple,
                    .blue,
                    .cyan,
                    .pink,
                    .orange,
                    .purple
                ],
                center: .center
            )
            .scaleEffect(1.6)
            .rotationEffect(.degrees(shift ? 360 : 0))
            .animation(
                .linear(duration: 60).repeatForever(autoreverses: false),
                value: shift
            )

            RadialGradient(
                colors: [
                    .black.opacity(0.1),
                    .black.opacity(0.6),
                    .black
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
        .onAppear { shift = true }
    }
}
