import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    struct CommunityMember: Identifiable {
        let id = UUID()
        let name: String
        let accent: Color
    }

    struct FeedItem: Identifiable {
        let id = UUID()
        let title: String
        let producer: String
        let caption: String
        let genre: String
        let bpm: Int
        let actionCount: String
        let messageCount: String
        let repostCount: String
        let gradient: [Color]
    }

    @Published var communityMembers: [CommunityMember] = [
        CommunityMember(name: "Nova", accent: Color(red: 0.62, green: 0.85, blue: 1.0)),
        CommunityMember(name: "Sage", accent: Color(red: 0.58, green: 0.74, blue: 1.0)),
        CommunityMember(name: "Velvet", accent: Color(red: 0.79, green: 0.62, blue: 1.0)),
        CommunityMember(name: "Rico", accent: Color(red: 0.53, green: 0.83, blue: 0.96)),
        CommunityMember(name: "Kai", accent: Color(red: 0.93, green: 0.72, blue: 0.48))
    ]

    @Published var feedItems: [FeedItem] = [
        FeedItem(
            title: "Neon Echo",
            producer: "Nova",
            caption: "Late-night drums and a clean topline pocket.",
            genre: "Trap",
            bpm: 142,
            actionCount: "8.4K",
            messageCount: "321",
            repostCount: "87",
            gradient: [Color(red: 0.14, green: 0.24, blue: 0.44), Color(red: 0.04, green: 0.07, blue: 0.16)]
        ),
        FeedItem(
            title: "Blue Room",
            producer: "Sage",
            caption: "Soft pads up front, tight bounce in the pocket.",
            genre: "R&B",
            bpm: 98,
            actionCount: "6.1K",
            messageCount: "204",
            repostCount: "51",
            gradient: [Color(red: 0.17, green: 0.20, blue: 0.35), Color(red: 0.05, green: 0.07, blue: 0.13)]
        ),
        FeedItem(
            title: "Skyline Fade",
            producer: "Velvet",
            caption: "Muted bass, glossy hats, and a clean hook space.",
            genre: "Lo-Fi",
            bpm: 86,
            actionCount: "4.8K",
            messageCount: "153",
            repostCount: "39",
            gradient: [Color(red: 0.21, green: 0.16, blue: 0.29), Color(red: 0.06, green: 0.05, blue: 0.1)]
        )
    ]
}
