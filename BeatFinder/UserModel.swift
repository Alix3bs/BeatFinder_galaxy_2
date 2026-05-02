import SwiftUI
import Combine

class UserModel: ObservableObject {
    @Published var displayName: String = "Tray3Beats"
    @Published var username: String = "tray3beats"
    @Published var bio: String = "Producer · Beatmaker · Always cooking 🔥"
    @Published var followers: Int = 245
    @Published var following: Int = 128
    @Published var profileImage: UIImage? = nil
}

struct ProfileUser: Identifiable, Hashable {
    let id: UUID
    let name: String
    let handle: String
    let genre: String
    let avatarName: String?
    let tags: [String]
    let followers: Int
    let following: Int
    let beats: [FeedBeat]

    static func stableID(for seed: String) -> UUID {
        let cleaned = seed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = UUID(uuidString: cleaned) {
            return direct
        }

        let bytes = Array(cleaned.utf8)
        var uuidBytes = [UInt8](repeating: 0, count: 16)

        for index in 0..<16 {
            let source = bytes.isEmpty ? UInt8(index & 0xFF) : bytes[index % bytes.count]
            let salt = UInt8(((index * 37) + 17) & 0xFF)
            uuidBytes[index] = source ^ salt
        }

        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        let uuid = uuidBytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: uuid_t.self, capacity: 1) { rebound in
                UUID(uuid: rebound.pointee)
            }
        }

        return uuid
    }
}
