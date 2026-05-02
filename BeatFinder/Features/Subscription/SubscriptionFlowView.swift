import SwiftUI

struct SubscriptionFlowView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SubscriptionFlowViewModel()

    var embeddedPresentation: Bool = false
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack {
            StarDotBackground()
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))

            LiquidGlassCard(cornerRadius: 34, contentPadding: 20, fillOpacity: 0.08) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    Group {
                        switch appState.subscription.flowStep {
                        case .plans:
                            SubscriptionPlanSelectionView(viewModel: viewModel)
                        case .membership:
                            MembershipView(viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .task {
            if case .idle = appState.subscription.loadState {
                await appState.subscriptionManager.loadProducts()
                appState.refreshSnapshots()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title(for: appState.subscription.flowStep))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("Top-down access to BeatFinder membership.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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
}
