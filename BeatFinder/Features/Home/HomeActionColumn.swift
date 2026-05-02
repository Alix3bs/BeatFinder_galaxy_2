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
