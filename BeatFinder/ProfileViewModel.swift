import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    struct Stat: Identifiable {
        let id = UUID()
        let value: String
        let title: String
    }

    let stats: [Stat] = [
        Stat(value: "24.5K", title: "Followers"),
        Stat(value: "312", title: "Following"),
        Stat(value: "48", title: "Tracks")
    ]

    let bio = "Producer and curator focused on polished drum pockets, fast references, and finding the right beat before the moment passes."

    func displayName(from session: SessionState) -> String {
        session.displayName.isEmpty ? "BeatFinder User" : session.displayName
    }

    func handle(from session: SessionState) -> String {
        "@\(session.username.isEmpty ? "beatfinder" : session.username)"
    }
}
