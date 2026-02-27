import SwiftUI

struct FeedView: View {

    struct BeatPost: Identifiable, Hashable {
        let id = UUID()
        let producer: String
        let title: String
        let subtitle: String
        let likes: String
        let plays: String
    }

    private let posts: [BeatPost] = [
        .init(producer: "Rama Low", title: "New Day", subtitle: "90s Boom Bap • LoFi • Chill Jazz", likes: "12.4K", plays: "88.1K"),
        .init(producer: "NeonDust", title: "Midnight Drift", subtitle: "Trap • Dark • Spacey", likes: "4.1K", plays: "31.5K"),
        .init(producer: "LunarBeats", title: "(untitled)", subtitle: "R&B • Smooth • Ambient", likes: "2.0K", plays: "18.2K"),
    ]

    // ✅ Selected item for navigation
    @State private var selectedPost: BeatPost? = nil

    var body: some View {
        ScreenContainer(
            spacing: BeatLayout.sectionSpacing,
            topPadding: BeatLayout.sectionSpacingTight,
            bottomPadding: 30
        ) {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.09, blue: 0.14),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .center
            )
        } content: {
            Text("Feed")
                .font(BeatTypography.screenTitle)
                .foregroundStyle(.white)

            ForEach(posts) { post in
                Button {
                    selectedPost = post
                } label: {
                    BeatPostCard(post: post)
                }
                .buttonStyle(.plain)
            }
        }
        .toolbar(.hidden, for: .navigationBar)

        // ✅ Push to BeatResultView when a post is selected
        .navigationDestination(item: $selectedPost) { post in
            BeatResultView(model: post.toBeatResultModel())
        }
    }
}

// MARK: - Card
private struct BeatPostCard: View {
    let post: FeedView.BeatPost

    var body: some View {
        SectionCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.7)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.producer)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(post.subtitle)
                        .font(BeatTypography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .foregroundStyle(.white.opacity(0.6))
            }

            ZStack {
                RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 210)

                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(post.plays) plays • \(post.likes) likes")
                        .font(BeatTypography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 14) {
                    Image(systemName: "heart")
                    Image(systemName: "lock.fill")
                    Image(systemName: "paperplane")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

// MARK: - Mapping to BeatResultModel
private extension FeedView.BeatPost {
    func toBeatResultModel() -> BeatResultModel {
        BeatResultModel(
            id: UUID().uuidString,
            title: title,
            artist: producer,
            bpm: 140,                 // placeholder
            genre: subtitle,          // using your subtitle for now
            releaseDate: Date(),      // placeholder
            artworkName: "nest_music" // later connect to real artwork
        )
    }
}
