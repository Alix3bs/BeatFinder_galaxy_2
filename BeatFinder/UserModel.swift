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
}
