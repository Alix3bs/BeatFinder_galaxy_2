import Foundation
import Supabase

final class AuthService: ObservableObject {
    @Published var session: Session?

    private let client = SupabaseManager.shared.client

    init() {
        Task { await refreshSession() }
    }

    @MainActor
    func refreshSession() async {
        self.session = try? await client.auth.session
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        session = response.session
        // create profile row
        if let user = response.user {
            try await client
                .from("profiles")
                .insert(["id": user.id.uuidString, "username": email.components(separatedBy: "@").first ?? "user"])
                .execute()
        }
    }

    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        session = response.session
    }

    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run { session = nil }
    }
}
