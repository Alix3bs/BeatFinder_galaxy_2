import SwiftUI

struct ExploreBeatCardView: View {
    let beat: FeedBeat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Album artwork background
                if let artworkName = beat.artworkName,
                   let uiImage = UIImage(named: artworkName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Fallback gradient if no artwork yet
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                // Price pill top-left
                Text(beat.price)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                    )
                    .foregroundColor(.white)
                    .padding(10),
                alignment: .topLeading
            )
            
            // Title + producer + stats
            Text(beat.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Text(beat.producer)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text("\(beat.plays) plays • \(beat.likes) likes")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
