import SwiftUI

struct MembershipView: View {
    @EnvironmentObject private var appState: AppState
    let viewModel: SubscriptionFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Membership Card")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.52))

            TiltCardView {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.42, blue: 0.74),
                                    Color(red: 0.08, green: 0.13, blue: 0.24)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("GO+")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            MembershipLogoLoop {
                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.96))
                            }
                        }

                        Spacer()

                        Text(appState.subscription.accessLevel == .goPlus ? "Membership Active" : "Ready to Activate")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))

                        Text(viewModel.selectedPlan(in: appState.subscription)?.title ?? "Plan")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)

                        Text(viewModel.selectedPlan(in: appState.subscription)?.priceText ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(22)
                }
                .frame(height: 220)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.benefits, id: \.self) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.54, green: 0.79, blue: 1.0))

                        Text(benefit)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                }
            }

            LiquidGlassButton(action: purchaseOrClose, cornerRadius: 20, fillOpacity: 0.12) {
                HStack {
                    Text(appState.subscription.accessLevel == .goPlus ? "Close Membership" : "Activate Membership")
                        .font(.system(size: 16, weight: .bold))

                    if appState.subscription.activePurchaseProductID != nil || appState.subscription.isRestoring {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                    }
                }
            }

            Button {
                withAnimation(MotionTokens.mediumEase) {
                    appState.subscription.flowStep = .plans
                }
            } label: {
                Text("Back to Plans")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.64))
            }
            .buttonStyle(.plain)

            if !appState.subscription.statusMessage.isEmpty {
                Text(appState.subscription.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private func purchaseOrClose() {
        if appState.subscription.accessLevel == .goPlus {
            appState.dismissSubscription()
        } else {
            Task {
                await appState.buySelectedPlan()
            }
        }
    }
}
