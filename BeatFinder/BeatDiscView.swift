import SwiftUI

// MARK: - Galaxy star model

struct GalaxyStar: Identifiable {
    let id = UUID()
    var angle: Double      // 0 ... 2π, around the circle
    var distance: Double   // 0 ... 1, how far from center
    var progress: Double   // 0 ... 1, how far it has "fallen"
    var speed: Double      // how fast the star moves
}

extension GalaxyStar {
    static func random() -> GalaxyStar {
        GalaxyStar(
            angle: Double.random(in: 0...(2 * .pi)),
            distance: Double.random(in: 0.15...0.95),
            progress: Double.random(in: 0...1),
            speed: Double.random(in: 0.01...0.03)
        )
    }
}

struct BeatDiscView: View {
    /// Is the beat currently playing?
    @Binding var isPlaying: Bool

    /// Neon outline color (white by default)
    var accentColor: Color = .white

    /// Optional album artwork (kept for later)
    var artworkImage: Image? = nil

    // MARK: - Shared speed config (use the SAME values
    // in your small-circle galaxy buttons too)
    private let starStep: Double = 0.15          // multiplier for speed
    private let starTick: TimeInterval = 0.08    // seconds per frame

    @State private var stars: [GalaxyStar] = (0..<80).map { _ in GalaxyStar.random() }
    @State private var starTimer: Timer?
    @State private var pulse: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2.0 - 4.0   // padding inside the outline

            ZStack {
                // STARFIELD (clipped to the big circle)
                GeometryReader { starGeo in
                    let starRadius = min(starGeo.size.width, starGeo.size.height) / 2

                    ForEach(stars) { star in
                        // base position on a circle
                        let baseX = cos(star.angle) * star.distance * starRadius
                        let baseY = sin(star.angle) * star.distance * starRadius

                        // progress moves star "down" (positive y)
                        let fall = (star.progress * 2 - 1) * starRadius  // -r ... +r

                        Circle()
                            .fill(Color.white)
                            .frame(width: 2.2, height: 2.2)
                            .position(
                                x: starGeo.size.width / 2 + baseX,
                                y: starGeo.size.height / 2 + baseY + fall
                            )
                            .opacity(0.8)
                    }
                }
                .clipShape(Circle())

                // NEON OUTLINE (pulsing)
                Circle()
                    .stroke(
                        accentColor.opacity(0.95),
                        lineWidth: 3
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .shadow(color: accentColor.opacity(0.8),
                            radius: 18, x: 0, y: 0)
                    .scaleEffect(pulse ? 1.04 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )

                // CENTER HOLE
                Circle()
                    .fill(Color.black.opacity(0.9))
                    .frame(width: geo.size.width * 0.08, height: geo.size.width * 0.08)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .shadow(color: Color.white.opacity(0.8), radius: 6)
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                pulse = true           // neon pulse
                startStarField()       // keep stars moving forever
            }
            .onDisappear {
                stopStarField()
            }
        }
    }

    // MARK: - Starfield logic

    private func startStarField() {
        stopStarField()

        starTimer = Timer.scheduledTimer(withTimeInterval: starTick, repeats: true) { _ in
            withAnimation(.linear(duration: starTick)) {
                for i in stars.indices {
                    // movement based on shared config
                    stars[i].progress += stars[i].speed * starStep

                    // when a star exits the bottom, respawn it somewhere new
                    if stars[i].progress > 1.0 {
                        stars[i] = .random()
                    }
                }
            }
        }
    }

    private func stopStarField() {
        starTimer?.invalidate()
        starTimer = nil
    }
}
