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

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if isMounted {
                    Color.black
                        .opacity(isPresented ? 0.52 : 0)
                        .ignoresSafeArea()
                        .onTapGesture {
                            guard dismissOnBackgroundTap else { return }
                            isPresented = false
                        }
                        .transition(.opacity)

                    content
                        .frame(maxWidth: min(proxy.size.width - 24, 460))
                        .padding(.horizontal, 12)
                        .padding(.top, proxy.safeAreaInsets.top + 12)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .offset(y: isPresented ? 0 : -proxy.size.height * 0.42)
                        .transition(.hangingFromTop)
                        .accessibilityIdentifier("subscriptionModal")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(isMounted)
            .animation(MotionTokens.topModalSpring, value: isPresented)
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
