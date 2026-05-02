import SwiftUI

struct LaunchFlowView: View {
    var onFinished: (() -> Void)? = nil

    @State private var logoOpacity = 0.0
    @State private var logoScale: CGFloat = 0.82
    @State private var wordOpacity = 0.0
    @State private var wordOffset: CGFloat = 14
    @State private var glowScale: CGFloat = 0.7
    @State private var glowOpacity = 0.0
    @State private var contentOpacity = 1.0
    @State private var contentScale: CGFloat = 1.0
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.29, green: 0.55, blue: 0.96).opacity(0.36),
                    Color(red: 0.12, green: 0.18, blue: 0.32).opacity(0.18),
                    .clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 260
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .blur(radius: 22)

            VStack(spacing: 16) {
                BeatFinderPlusBrandMark(
                    width: 144,
                    height: 88,
                    strokeColor: .white.opacity(0.88),
                    foregroundColor: .white.opacity(0.88),
                    crownColor: Color(red: 0.62, green: 0.82, blue: 1.0),
                    lineWidth: 3.2
                )
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .shadow(color: Color.white.opacity(0.12), radius: 18, x: 0, y: 10)

                Text("BeatFinder")
                    .font(.custom("HelveticaNeue-Bold", size: 34))
                    .foregroundStyle(.white.opacity(0.96))
                    .opacity(wordOpacity)
                    .offset(y: wordOffset)
            }
            .padding(.horizontal, 24)
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .onAppear {
            runAnimation()
        }
    }

    private func runAnimation() {
        hasFinished = false

        withAnimation(.spring(response: 0.68, dampingFraction: 0.82)) {
            glowOpacity = 1
            glowScale = 1
            logoOpacity = 1
            logoScale = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeOut(duration: 0.34)) {
                wordOpacity = 1
                wordOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) {
            withAnimation(.easeInOut(duration: 0.28)) {
                glowScale = 1.08
                contentScale = 1.02
                contentOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.46) {
            guard !hasFinished else { return }
            hasFinished = true
            onFinished?()
        }
    }
}

#Preview {
    LaunchFlowView()
}
