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
