import SwiftUI

struct ThemeKey: EnvironmentKey {
    static let defaultValue: String = "NeonPurple"
}

extension EnvironmentValues {
    var selectedTheme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeProvider: ViewModifier {
    @AppStorage("selectedTheme") private var selectedTheme: String = "NeonPurple"

    func body(content: Content) -> some View {
        content.environment(\.selectedTheme, selectedTheme)
    }
}

extension View {
    func applyTheme() -> some View {
        self.modifier(ThemeProvider())
    }
}
