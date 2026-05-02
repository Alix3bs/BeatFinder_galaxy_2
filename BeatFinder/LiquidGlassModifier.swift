import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderOpacity: Double

    func body(content: Content) -> some View {
        content
            .liquidGlassSurface(cornerRadius: cornerRadius, strokeOpacity: borderOpacity, shadowOpacity: 0.24)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 16, borderOpacity: Double = 0.2) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}
