import SwiftUI
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    enum ThemeOption: String, CaseIterable, Identifiable {
        case neonPurple = "NeonPurple"
        case crimson = "Crimson"
        case sunset = "Sunset"
        case electricGreen = "ElectricGreen"
        case ocean = "Ocean"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .neonPurple: return "Neon Purple"
            case .crimson: return "Crimson"
            case .sunset: return "Sunset"
            case .electricGreen: return "Electric Green"
            case .ocean: return "Ocean"
            }
        }
    }

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }
    }

    @AppStorage("selectedTheme") private var storedTheme: String = ThemeOption.neonPurple.rawValue
    @AppStorage("themeMode") private var storedAppearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("settings.haptics") private var storedHapticsEnabled: Bool = true
    @AppStorage("settings.autoplayPreviews") private var storedAutoplayPreviews: Bool = false
    @AppStorage("settings.explicitFilter") private var storedExplicitFilter: Bool = false

    @Published var selectedTheme: String = ThemeOption.neonPurple.rawValue {
        didSet {
            guard selectedTheme != oldValue else { return }
            storedTheme = selectedTheme
        }
    }

    @Published var appearanceMode: String = AppearanceMode.system.rawValue {
        didSet {
            guard appearanceMode != oldValue else { return }
            storedAppearanceMode = appearanceMode
        }
    }

    @Published var hapticsEnabled: Bool = true {
        didSet {
            guard hapticsEnabled != oldValue else { return }
            storedHapticsEnabled = hapticsEnabled
        }
    }

    @Published var autoplayPreviews: Bool = false {
        didSet {
            guard autoplayPreviews != oldValue else { return }
            storedAutoplayPreviews = autoplayPreviews
        }
    }

    @Published var explicitFilterEnabled: Bool = false {
        didSet {
            guard explicitFilterEnabled != oldValue else { return }
            storedExplicitFilter = explicitFilterEnabled
        }
    }

    init() {
        selectedTheme = Self.validThemeOrDefault(storedTheme)
        appearanceMode = Self.validAppearanceOrDefault(storedAppearanceMode)
        hapticsEnabled = storedHapticsEnabled
        autoplayPreviews = storedAutoplayPreviews
        explicitFilterEnabled = storedExplicitFilter
    }

    var selectedThemeOption: ThemeOption {
        get { ThemeOption(rawValue: selectedTheme) ?? .neonPurple }
        set { selectedTheme = newValue.rawValue }
    }

    var appearanceModeOption: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceMode) ?? .system }
        set { appearanceMode = newValue.rawValue }
    }

    var preferredColorScheme: ColorScheme? {
        ThemeManager.colorScheme(for: appearanceMode)
    }

    var toolbarColorScheme: ColorScheme {
        switch appearanceModeOption {
        case .light:
            return .light
        case .dark, .system:
            return .dark
        }
    }

    private static func validThemeOrDefault(_ value: String) -> String {
        ThemeOption(rawValue: value)?.rawValue ?? ThemeOption.neonPurple.rawValue
    }

    private static func validAppearanceOrDefault(_ value: String) -> String {
        AppearanceMode(rawValue: value)?.rawValue ?? AppearanceMode.system.rawValue
    }
}
