import SwiftUI

private struct TopHangTransitionModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
    }
}

extension AnyTransition {
    static var hangingFromTop: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: TopHangTransitionModifier(offset: -180, opacity: 0.0, scale: 0.96),
                identity: TopHangTransitionModifier(offset: 0, opacity: 1.0, scale: 1.0)
            ),
            removal: .modifier(
                active: TopHangTransitionModifier(offset: -120, opacity: 0.0, scale: 0.98),
                identity: TopHangTransitionModifier(offset: 0, opacity: 1.0, scale: 1.0)
            )
        )
    }
}

struct GlassModalSheet<Content: View>: View {
    @Binding var isPresented: Bool
    var dismissOnBackgroundTap: Bool = true
    @ViewBuilder var content: Content

    @State private var isMounted = false
    private let modalAnimation = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.18)

    var body: some View {
        GeometryReader { proxy in
            let modalWidth = min(
                max(0, proxy.size.width - (proxy.size.width >= 768 ? 48 : 24)),
                proxy.size.width >= 768 ? BeatLayout.modalContentMaxWidth : 460
            )
            let topPadding = proxy.size.width >= 768 ? 32 : proxy.safeAreaInsets.top + 12
            let bottomPadding = max(proxy.safeAreaInsets.bottom + 12, 20)

            ZStack(alignment: proxy.size.width >= 768 ? .center : .top) {
                if isMounted {
                    Color.black
                        .opacity(isPresented ? 0.66 : 0)
                        .ignoresSafeArea()
                        .onTapGesture {
                            guard dismissOnBackgroundTap else { return }
                            isPresented = false
                        }
                        .transition(.opacity)

                    content
                        .frame(maxWidth: modalWidth)
                        .padding(.horizontal, proxy.size.width >= 768 ? 24 : 12)
                        .padding(.top, topPadding)
                        .padding(.bottom, bottomPadding)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: proxy.size.width >= 768 ? .center : .top
                        )
                        .scaleEffect(isPresented ? 1 : 0.975)
                        .offset(y: isPresented ? 0 : 10)
                        .opacity(isPresented ? 1 : 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .accessibilityIdentifier("subscriptionModal")
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: proxy.size.width >= 768 ? .center : .top
            )
            .allowsHitTesting(isMounted)
            .animation(modalAnimation, value: isPresented)
            .onAppear {
                if isPresented {
                    isMounted = true
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    isMounted = true
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(Int(MotionTokens.slowDuration * 1_000)))
                        guard !isPresented else { return }
                        isMounted = false
                    }
                }
            }
        }
    }
}
