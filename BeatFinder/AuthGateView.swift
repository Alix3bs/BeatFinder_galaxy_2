import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var saved: SavedMatchesStore

    var body: some View {
        Group {
            // If not signed in, show login
            if auth.sessionUserId == nil {
                GalaxyEntryView()
                    .environmentObject(auth)
            } else {
                // Signed in -> your real app
                ContentView()
                    .environmentObject(auth)
            }
        }
        .task {
            await auth.bootstrap()
            await saved.syncFromRemote(userId: auth.sessionUserId)
        }
        .onChange(of: auth.sessionUserId) { _, userId in
            Task {
                await saved.syncFromRemote(userId: userId)
            }
        }
    }
}
