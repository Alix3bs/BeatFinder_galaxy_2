import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack(path: $appState.homePath) {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)
            .accessibilityIdentifier("tab.home")

            NavigationStack(path: $appState.uploadPath) {
                UploadView()
                    .navigationDestination(for: UploadRoute.self) { route in
                        switch route {
                        case .result(let result):
                            UploadResultView(model: result)
                        }
                    }
            }
            .tabItem {
                Label("Upload", systemImage: "plus.circle.fill")
            }
            .tag(AppTab.upload)
            .accessibilityIdentifier("tab.upload")

            NavigationStack(path: $appState.profilePath) {
                ProfileView()
                    .navigationDestination(for: ProfileRoute.self) { route in
                        switch route {
                        case .settings:
                            SettingsView()
                        case .wallet:
                            WalletView()
                        }
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(AppTab.profile)
            .accessibilityIdentifier("tab.profile")

            NavigationStack(path: $appState.safePath) {
                SafeView()
            }
            .tabItem {
                Label("Safe", systemImage: "lock.shield.fill")
            }
            .tag(AppTab.safe)
            .accessibilityIdentifier("tab.safe")
        }
        .tint(Color(red: 0.54, green: 0.79, blue: 1.0))
        .toolbarBackground(Color.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Color.black.ignoresSafeArea())
    }
}
