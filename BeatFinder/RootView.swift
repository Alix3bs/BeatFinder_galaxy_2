import SwiftUI

/// Single app root. AuthGateView decides whether to show the galaxy entry
/// screens or the main app based on the Supabase session.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        AuthGateView()
            .environment(\.selectedTheme, settings.selectedTheme)
            .preferredColorScheme(settings.preferredColorScheme)
    }
}
