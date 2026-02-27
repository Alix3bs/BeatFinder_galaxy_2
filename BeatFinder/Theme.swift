import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case purple, red, orange, green, blue
    var id: String { rawValue }

    var background: Color {
        switch self {
        case .purple: return Color(red: 120/255, green: 41/255, blue: 255/255)
        case .red:    return Color(red: 230/255, green: 40/255, blue: 60/255)
        case .orange: return Color(red: 245/255, green: 140/255, blue: 20/255)
        case .green:  return Color(red: 40/255, green: 190/255, blue: 90/255)
        case .blue:   return Color(red: 40/255, green: 130/255, blue: 255/255)
        }
    }

    /// High contrast text color for the background
    var textColor: Color {
        switch self {
        case .orange, .green: return .black   // light backgrounds
        default:              return .white   // dark backgrounds
        }
    }

    var cardBackground: Color {
        background.opacity(0.25)
    }
}

final class AppThemeManager: ObservableObject {
    @Published var theme: AppTheme = .purple
}

