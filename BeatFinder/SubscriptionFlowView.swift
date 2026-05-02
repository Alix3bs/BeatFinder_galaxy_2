import SwiftUI

struct SubscriptionFlowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = SubscriptionFlowViewModel()

    var embeddedPresentation: Bool = false
    var onClose: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius: CGFloat = 34

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.24, blue: 0.44).opacity(0.18),
                                        Color.clear,
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                StarDotBackground()
                    .opacity(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        stepContent
                    }
                    .padding(horizontalSizeClass == .regular ? 28 : 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 14))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.34), radius: 28, x: 0, y: 18)
        }
        .task {
            if case .idle = appState.subscription.loadState {
                await appState.subscriptionManager.loadProducts()
                appState.refreshSnapshots()
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                headerCopy
                Spacer()
                closeButton
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    closeButton
                }
                headerCopy
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.title(for: appState.subscription.flowStep))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(headerSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private var closeButton: some View {
        Button {
            BeatHaptics.tap()
            close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private func close() {
        if let onClose {
            onClose()
        } else if embeddedPresentation {
            appState.dismissSubscription()
        } else {
            appState.dismissSubscription()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        ZStack {
            switch appState.subscription.flowStep {
            case .plans:
                SubscriptionPlanSelectionView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            case .membership:
                MembershipView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(MotionTokens.topModalSpring, value: appState.subscription.flowStep)
    }

    private var headerSubtitle: String {
        switch appState.subscription.flowStep {
        case .plans:
            return "Choose a plan and move straight into the membership card."
        case .membership:
            return "Review membership details, then activate or manage the subscription."
        }
    }
}
