import SwiftUI

// Re-usable neon galaxy colors + helpers
enum GalaxyTheme {
    static let c1 = Color(red: 0.56, green: 1.0, blue: 0.97) // cyan
    static let c2 = Color(red: 0.96, green: 0.50, blue: 1.00) // magenta
    static let c3 = Color(red: 0.25, green: 0.80, blue: 1.00) // blue

    static var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [c1, c2, c3, c1]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Animated neon gradient you can use anywhere as a background
struct AnimatedGalaxyCapsule: View {
    @State private var hue: Double = 0

    var body: some View {
        GalaxyTheme.gradient
            .hueRotation(.degrees(hue))
            .animation(
                .linear(duration: 8)
                    .repeatForever(autoreverses: false),
                value: hue
            )
            .onAppear { hue = 360 }
    }
}

