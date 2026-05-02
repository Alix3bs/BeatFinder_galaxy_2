import SwiftUI

private struct LiquidGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let strokeOpacity: Double
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(fillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.35),
                                Color.white.opacity(strokeOpacity * 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 12, x: 0, y: 8)
    }
}

extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat = 24,
        fillOpacity: Double = 0.06,
        strokeOpacity: Double = 0.16,
        shadowOpacity: Double = 0.24
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                strokeOpacity: strokeOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }
}

struct LiquidGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var contentPadding: CGFloat = 18
    var fillOpacity: Double = 0.06
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BeatLayout.sectionSpacingTight) {
            content
        }
        .padding(contentPadding)
        .liquidGlassSurface(cornerRadius: cornerRadius, fillOpacity: fillOpacity)
    }
}
