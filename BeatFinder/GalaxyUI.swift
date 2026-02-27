import SwiftUI

struct GalaxyScreen<Content: View>: View {
    // Kept for compatibility if you later decide to ship a GIF again.
    // The current build uses an animated SwiftUI gradient background so the UI
    // won't silently break if the GIF asset is missing.
    var gifName: String? = nil
    var dim: Double = 0.55
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AnimatedGalaxyBackground().ignoresSafeArea()
            Color.black.opacity(dim).ignoresSafeArea()
            content
        }
    }
}

struct FrostCard: ViewModifier {
    var corner: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
    }
}
extension View {
    func frostCard(corner: CGFloat = 20) -> some View { modifier(FrostCard(corner: corner)) }
}
