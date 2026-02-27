import SwiftUI

struct BeatTheme {
    // Slightly soft neon white
    static let neonWhite = Color.white.opacity(0.95)
    
    // Optional: different glow colors per speed
    static func color(forSpeed speed: Double) -> Color {
        switch speed {
        case 0.5:  return Color.blue.opacity(0.9)
        case 1.0:  return neonWhite
        case 1.25: return Color.purple.opacity(0.9)
        case 1.5:  return Color.green.opacity(0.9)
        default:   return neonWhite
        }
    }
}

