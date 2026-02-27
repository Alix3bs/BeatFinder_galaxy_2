import Foundation
import Supabase
import UIKit

struct BeatInsert: Encodable {
    let user_id: String
    let title: String
    let artist: String?
    let bpm: Int?
    let genre: String?
    let artwork_path: String?
    let audio_path: String?
}

final class BeatService {
    private let client = SupabaseManager.shared.client

    func uploadArtwork(userId: String, image: UIImage) async throws -> String {
        let data = image.jpegData(compressionQuality: 0.9) ?? Data()
        let path = "\(userId)/\(UUID().uuidString).jpg"

        try await client.storage
            .from("artworks")
            .upload(
                path,
                file: data,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )

        return path
    }

    func uploadAudio(userId: String, fileURL: URL) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.isEmpty ? "mp3" : fileURL.pathExtension
        let path = "\(userId)/\(UUID().uuidString).\(ext)"

        try await client.storage
            .from("audio")
            .upload(
                path,
                file: data,
                options: FileOptions(contentType: "audio/\(ext)", upsert: false)
            )

        return path
    }

    func createBeatRow(_ beat: BeatInsert) async throws {
        try await client
            .from("beats")
            .insert(beat)
            .execute()
    }

    // Signed URL to display private storage
    func signedArtworkURL(path: String) async throws -> URL {
        let res = try await client.storage.from("artworks").createSignedURL(path: path, expiresIn: 60 * 60)
        return res.signedURL
    }

    // Toggle like in beat_likes
    func toggleLike(beatId: String, userId: String, isLiked: Bool) async throws {
        if isLiked {
            try await client.from("beat_likes")
                .delete()
                .eq("user_id", value: userId)
                .eq("beat_id", value: beatId)
                .execute()
        } else {
            try await client.from("beat_likes")
                .insert(["user_id": userId, "beat_id": beatId])
                .execute()
        }
    }

    // Toggle save in beat_saves
    func toggleSave(beatId: String, userId: String, isSaved: Bool) async throws {
        if isSaved {
            try await client.from("beat_saves")
                .delete()
                .eq("user_id", value: userId)
                .eq("beat_id", value: beatId)
                .execute()
        } else {
            try await client.from("beat_saves")
                .insert(["user_id": userId, "beat_id": beatId])
                .execute()
        }
    }
}
