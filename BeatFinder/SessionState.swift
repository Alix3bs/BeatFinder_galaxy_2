import Foundation

struct SessionState: Equatable {
    var userID: UUID?
    var displayName: String
    var username: String
    var avatarURL: URL?
    var isVerified: Bool

    var isAuthenticated: Bool { userID != nil }
}
