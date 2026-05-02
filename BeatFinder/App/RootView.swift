import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var savedMatches: SavedMatchesStore
    @State private var hasBootstrapped = false

    var body: some View {
        ZStack {
            Group {
                if appState.session.isAuthenticated {
                    ContentView()
                } else {
                    GalaxyEntryView()
                        .environmentObject(appState.authStore)
                }
            }

            GlassModalSheet(
                isPresented: Binding(
                    get: { appState.session.isAuthenticated && appState.subscription.isPresented },
                    set: { isPresented in
                        if !isPresented {
                            appState.dismissSubscription()
                        }
                    }
                )
            ) {
                SubscriptionFlowView()
                    .environmentObject(appState)
            }
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true
            await appState.bootstrap()
            await savedMatches.syncFromRemote(userId: appState.session.userID)
        }
        .onChange(of: appState.session.userID) { _, userID in
            Task {
                await savedMatches.syncFromRemote(userId: userID)
            }
        }
        .preferredColorScheme(.dark)
    }
}
