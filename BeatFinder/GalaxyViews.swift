import SwiftUI
import Combine

// MARK: - Simple StarField for small UI elements

struct StarField: View {
    var size: CGFloat
    
    // MARK: - Shared speed config (matches BeatDiscView)
    private static let starStep: Double = 0.15          // multiplier for speed
    private static let starTick: TimeInterval = 0.10    // seconds per frame
    
    @State private var stars: [StarFieldStar] = []
    private let timer = Timer.publish(every: Self.starTick, on: .main, in: .common).autoconnect()
    
    private struct StarFieldStar: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var size: CGFloat
        var opacity: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear {
            if stars.isEmpty {
                stars = makeStars(count: 90, in: size)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: Self.starTick)) {
                for i in stars.indices {
                    stars[i].y += stars[i].speed * Self.starStep
                    if stars[i].y > size + 8 {
                        stars[i].y = -8
                        stars[i].x = CGFloat.random(in: 0...size)
                    }
                }
            }
        }
    }
    
    private func makeStars(count: Int, in size: CGFloat) -> [StarFieldStar] {
        (0..<count).map { _ in
            StarFieldStar(
                x: CGFloat.random(in: 0...size),
                y: CGFloat.random(in: 0...size),
                speed: CGFloat.random(in: 0.4...0.9),
                size: CGFloat.random(in: 1.0...2.4),
                opacity: Double.random(in: 0.45...1.0)
            )
        }
    }
}

// MARK: - Animated starfield (slow, space-like)

struct GalaxyStarfield: View {
    var intensity: Double = 1.0   // you can tweak this if it feels too strong
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, size in
                let starCount = 90
                
                for i in 0..<starCount {
                    let seed = Double(i)
                    
                    // spiral / orbit style movement, but SLOW
                    let baseRadius = min(size.width, size.height) * 0.45
                    let angle = (t * 0.03) + seed * 0.35   // 0.03 = slow, change to 0.02 for even slower
                    let depth = 0.4 + 0.6 * sin(seed * 0.7)
                    
                    let x = size.width * 0.5 + CGFloat(cos(angle) * baseRadius * depth)
                    let y = size.height * 0.5 + CGFloat(sin(angle) * baseRadius * depth)
                    
                    let radius = CGFloat(0.4 + 1.6 * (0.5 + sin(seed))) // different star sizes
                    let alpha = 0.35 + 0.4 * (0.5 + sin(seed * 1.9 + t * 0.6))
                    
                    let rect = CGRect(x: x - radius,
                                      y: y - radius,
                                      width: radius * 2,
                                      height: radius * 2)
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(alpha * intensity))
                    )
                }
            }
        }
    }
}

// MARK: - Circle & Capsule galaxy backgrounds

struct GalaxyCircleBackground: View {
    var body: some View {
        ZStack {
            // Base galaxy texture
            Image("galaxyTexture")
                .resizable()
                .scaledToFill()
                // very slow rotation so it feels alive, not spinning crazy
                .rotationEffect(.degrees(2))
                .blur(radius: 1.5)
            
            // Animated stars on top
            GalaxyStarfield()
                .blendMode(.screen)
        }
        .clipped()
    }
}

// Small circular galaxy (for play button background, etc.)
struct GalaxyOrbBackground: View {
    var isPlaying: Bool
    var size: CGFloat = 72
    
    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            StarField(size: size)
                .clipShape(Circle())    // <-- important
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .shadow(color: Color.white.opacity(0.6), radius: 8)
        }
        .frame(width: size, height: size)
    }
}

// Capsule galaxy (for speed & price pills)
struct GalaxyCapsuleBackground: View {
    var isActive: Bool
    var width: CGFloat = 80
    var height: CGFloat = 30
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black)
            
            // always animated stars
            StarField(size: width)
                .mask(Capsule())
            
            Capsule()
                .stroke(Color.white.opacity(isActive ? 0.95 : 0.35), lineWidth: 1.5)
                .shadow(color: Color.white.opacity(isActive ? 0.7 : 0.2), radius: 6)
        }
        .frame(width: width, height: height)
    }
}

