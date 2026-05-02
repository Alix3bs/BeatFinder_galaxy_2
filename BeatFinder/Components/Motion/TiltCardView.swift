import SwiftUI

struct TiltCardView<Content: View>: View {
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: Content

    @StateObject private var motionController = TiltMotionController()

    var body: some View {
        content
            .rotation3DEffect(.degrees(motionController.orientation.xDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.75)
            .rotation3DEffect(.degrees(motionController.orientation.yDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
            .shadow(
                color: Color.black.opacity(0.18),
                radius: 14,
                x: CGFloat(motionController.orientation.yDegrees) * 0.3,
                y: 10 + CGFloat(abs(motionController.orientation.xDegrees)) * 0.25
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(MotionTokens.mediumEase, value: motionController.orientation)
            .onAppear {
                motionController.start()
            }
            .onDisappear {
                motionController.stop()
            }
    }
}
