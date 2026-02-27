import SwiftUI

struct FeedHeaderView: View {
    var onMessagesTapped: () -> Void

    var body: some View {
        HStack {
            // Left: title
            Text("Feed")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Right: messages icon (BandLab style)
            Button(action: onMessagesTapped) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12)) // soft gray pill, like BandLab
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

