import Foundation
import Combine
import UIKit
import Supabase

@MainActor
final class AuthStore: ObservableObject {

    struct Profile: Codable {
        let id: UUID
        var username: String?
        var avatar_url: String?
        var verified: Bool?
    }

    @Published var sessionUserId: UUID?
    @Published var profile: Profile?
    @Published var authError: String?

    private let client = SupabaseManager.client

    func refreshSession() async {
        do {
            let session = try await client.auth.session
            sessionUserId = session.user.id
        } catch {
            sessionUserId = nil
        }
    }

    @MainActor
    func bootstrap() async {
        await refreshSession()
        if sessionUserId != nil {
            await ensureProfileRowExists()
            await fetchProfile()
        }
    }

    func signUp(email: String, password: String) async throws {
        authError = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            await bootstrap()
        } catch {
            authError = error.localizedDescription
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        authError = nil
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            await bootstrap()
        } catch {
            authError = error.localizedDescription
            throw error
        }
    }

    private func ensureProfileRowExists() async {
        guard let uid = sessionUserId else { return }
        do {
            try await client
                .from("profiles")
                .upsert(["id": uid.uuidString])
                .execute()
        } catch {
            // If RLS prevents this, you'll need appropriate policies.
        }
    }

    func fetchProfile() async {
        do {
            if sessionUserId == nil { await refreshSession() }
            guard let uid = sessionUserId else { return }

            let rows: [Profile] = try await client
                .from("profiles")
                .select()
                .eq("id", value: uid.uuidString)
                .limit(1)
                .execute()
                .value

            if var first = rows.first {
                if let metadataUsername = await readMetadataUsername() {
                    first.username = metadataUsername
                }
                profile = first
            } else {
                profile = Profile(
                    id: uid,
                    username: await readMetadataUsername(),
                    avatar_url: nil,
                    verified: nil
                )
            }
        } catch {
            // Fallback to auth metadata when profile table read fails.
            if let uid = sessionUserId {
                profile = Profile(
                    id: uid,
                    username: await readMetadataUsername(),
                    avatar_url: profile?.avatar_url,
                    verified: profile?.verified
                )
            }
        }
    }

    func updateUsername(_ username: String) async throws {
        if sessionUserId == nil { await refreshSession() }
        guard let uid = sessionUserId else { return }

        var metadataUpdated = false
        do {
            _ = try await client.auth.update(
                user: UserAttributes(
                    data: ["username": .string(username)]
                )
            )
            metadataUpdated = true
        } catch {
            // Continue; some projects block metadata updates.
        }

        do {
            try await client
                .from("profiles")
                .update(["username": username])
                .eq("id", value: uid.uuidString)
                .execute()
        } catch {
            // If metadata update succeeded, keep UX working even when profile triggers/policies fail.
            guard metadataUpdated else {
                throw error
            }
        }

        await fetchProfile()
    }

    func updatePassword(_ newPassword: String) async throws {
        authError = nil

        do {
            _ = try await client.auth.update(
                user: UserAttributes(password: newPassword)
            )
        } catch {
            authError = error.localizedDescription
            throw error
        }
    }

    // Upload avatar to Storage bucket "avatars"
    func uploadAvatar(image: UIImage) async throws {
        if sessionUserId == nil { await refreshSession() }
        guard let uid = sessionUserId else { return }
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }

        let path = "\(uid.uuidString).jpg"

        try await client.storage
            .from("avatars")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        // store the path in profiles.avatar_url
        try await client
            .from("profiles")
            .update(["avatar_url": path])
            .eq("id", value: uid.uuidString)
            .execute()

        await fetchProfile()
    }

    // Signed URL for displaying private avatars
    func signedAvatarURL() async -> URL? {
        guard let path = profile?.avatar_url, !path.isEmpty else { return nil }
        do {
            let signed = try await client.storage
                .from("avatars")
                .createSignedURL(path: path, expiresIn: 60 * 60)
            return signed
        } catch {
            return nil
        }
    }

    func signOut() async {
        authError = nil
        do {
            try await client.auth.signOut()
        } catch {
            authError = error.localizedDescription
        }
        sessionUserId = nil
        profile = nil
    }

    func currentEmail() async -> String? {
        do {
            let session = try await client.auth.session
            let email = session.user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let email, !email.isEmpty {
                return email
            }
            return nil
        } catch {
            return nil
        }
    }

    private func readMetadataUsername() async -> String? {
        do {
            let session = try await client.auth.session
            let username = session.user.userMetadata["username"]?.stringValue
            let cleaned = username?.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned?.isEmpty == true ? nil : cleaned
        } catch {
            return nil
        }
    }
}
