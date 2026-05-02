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
import SwiftUI

struct HomeCommunityRow: View {
    let members: [HomeViewModel.CommunityMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(members) { member in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [member.accent, member.accent.opacity(0.28)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Text(String(member.name.prefix(1)))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .frame(width: 64, height: 64)

                            Text(member.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
import SwiftUI

struct HomeActionColumn: View {
    let item: HomeViewModel.FeedItem

    var body: some View {
        VStack(spacing: 16) {
            actionBubble(systemImage: "heart.fill", count: item.actionCount)
            actionBubble(systemImage: "bubble.left.fill", count: item.messageCount)
            actionBubble(systemImage: "arrow.2.squarepath", count: item.repostCount)
        }
    }

    private func actionBubble(systemImage: String, count: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())

            Text(count)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
import SwiftUI

struct HomeFeedCardView: View {
    let item: HomeViewModel.FeedItem

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: item.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.genre.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.68))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        Text("by \(item.producer)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Text(item.caption)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        pill(title: "\(item.bpm) BPM")
                        pill(title: item.genre)
                    }
                }
                .padding(22)
            }
            .frame(height: 420)
            .frame(maxWidth: .infinity)

            HomeActionColumn(item: item)
                .padding(.bottom, 20)
        }
    }

    private func pill(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
    }
}
import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    HomeCommunityRow(members: viewModel.communityMembers)

                    VStack(spacing: 18) {
                        ForEach(viewModel.feedItems) { item in
                            HomeFeedCardView(item: item)
                        }
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Home")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text("Community picks and recent finds")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
