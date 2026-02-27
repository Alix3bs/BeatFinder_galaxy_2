import Foundation
import Combine
import Supabase
import SwiftUI

@MainActor
final class LikeService: ObservableObject {
    @Published private(set) var likedBeatIds: Set<UUID> = []
    @Published var statusText: String = ""

    private var loadedForUserId: UUID?

    func loadLikes(for userId: UUID, force: Bool = false) async {
        if !force, loadedForUserId == userId, !likedBeatIds.isEmpty {
            return
        }

        do {
            let rows: [LikeRow] = try await SupabaseManager.client
                .from("beat_likes")
                .select("beat_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            likedBeatIds = Set(rows.map(\.beat_id))
            loadedForUserId = userId
            statusText = ""
        } catch {
            statusText = "Could not load likes."
        }
    }

    func toggleLike(userId: UUID, beatId: UUID) async {
        let shouldUnlike = likedBeatIds.contains(beatId)

        if shouldUnlike {
            likedBeatIds.remove(beatId)
        } else {
            likedBeatIds.insert(beatId)
        }

        do {
            if shouldUnlike {
                _ = try await SupabaseManager.client
                    .from("beat_likes")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("beat_id", value: beatId.uuidString)
                    .execute()
            } else {
                let row = LikeInsertRow(
                    user_id: userId.uuidString,
                    beat_id: beatId.uuidString
                )
                _ = try await SupabaseManager.client
                    .from("beat_likes")
                    .insert(row)
                    .execute()
            }
            statusText = ""
        } catch {
            // Rollback local state if remote write fails.
            if shouldUnlike {
                likedBeatIds.insert(beatId)
            } else {
                likedBeatIds.remove(beatId)
            }
            statusText = "Could not update like."
        }
    }

    func isLiked(_ beatId: UUID) -> Bool {
        likedBeatIds.contains(beatId)
    }
}

private struct LikeRow: Decodable {
    let beat_id: UUID
}

private struct LikeInsertRow: Encodable {
    let user_id: String
    let beat_id: String
}

struct LikeButton: View {
    let beatId: UUID
    let userId: UUID

    @EnvironmentObject private var likes: LikeService

    var body: some View {
        Button {
            Task { await likes.toggleLike(userId: userId, beatId: beatId) }
        } label: {
            Image(systemName: likes.isLiked(beatId) ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(likes.isLiked(beatId) ? Color.red : Color.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
