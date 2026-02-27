import SwiftUI

struct ThemeManager {
    static func accentColor(for theme: String) -> Color {
        switch theme {
        case "Crimson": return .red
        case "Sunset": return .orange
        case "ElectricGreen": return .green
        case "Ocean": return .blue
        default: return Color.purple
        }
    }

    static func backgroundGradient(for theme: String) -> LinearGradient {
        switch theme {
        case "Crimson":
            return LinearGradient(colors: [.red.opacity(0.6), .black],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Sunset":
            return LinearGradient(colors: [.orange, .pink.opacity(0.6)],
                                  startPoint: .top, endPoint: .bottom)
        case "ElectricGreen":
            return LinearGradient(colors: [.green.opacity(0.6), .black],
                                  startPoint: .top, endPoint: .bottom)
        case "Ocean":
            return LinearGradient(colors: [.blue.opacity(0.7), .black],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.purple, .black],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    static func colorScheme(for mode: String) -> ColorScheme? {
        switch mode {
        case "Light":
            return .light
        case "Dark":
            return .dark
        default:
            return nil
        }
    }
}
