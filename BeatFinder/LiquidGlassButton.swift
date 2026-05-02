import SwiftUI

struct LiquidGlassButton<Label: View>: View {
    let action: () -> Void
    var cornerRadius: CGFloat = 18
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 14
    var fillOpacity: Double = 0.08
    var foregroundStyle: AnyShapeStyle = AnyShapeStyle(Color.white)
    @ViewBuilder var label: () -> Label

    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            BeatHaptics.tap()
            action()
        } label: {
            label()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(foregroundStyle)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
        .scaleEffect(isPressed ? 0.985 : 1)
        .opacity(isEnabled ? 1 : 0.56)
        .animation(MotionTokens.fastEase, value: isPressed)
        .animation(MotionTokens.fastEase, value: isEnabled)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
        )
        .liquidGlassSurface(cornerRadius: cornerRadius, fillOpacity: fillOpacity, strokeOpacity: 0.18, shadowOpacity: 0.2)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}
