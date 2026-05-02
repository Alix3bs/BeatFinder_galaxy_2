import StoreKit
import SwiftUI

struct MembershipView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let viewModel: SubscriptionFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        membershipCard
                            .frame(maxWidth: .infinity)

                        membershipDetails
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        membershipCard
                        membershipDetails
                    }
                }
            }
        }
    }

    private var membershipCard: some View {
        TiltCardView {
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.26, blue: 0.48),
                                Color(red: 0.07, green: 0.10, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(displayTitle)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(appState.subscription.accessLevel == .goPlus ? "Membership Active" : "Ready to Activate")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.66))
                                }

                                Spacer()

                                Text(appState.subscription.accessLevel == .goPlus ? "ACTIVE" : "GO+")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Capsule())
                            }

                            featureBox

                            HStack {
                                Text(viewModel.selectedPlan(in: appState.subscription)?.priceText ?? "")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.82))

                                Spacer()

                                Text("BeatFinder Plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.54))
                            }
                        }
                        .padding(22)
                    }
            }
            .frame(height: horizontalSizeClass == .regular ? 470 : 410)
        }
    }

    private var featureBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Circle()
                .fill(Color(red: 0.54, green: 0.79, blue: 1.0).opacity(0.20))
                .frame(width: horizontalSizeClass == .regular ? 220 : 180, height: horizontalSizeClass == .regular ? 220 : 180)
                .blur(radius: 42)

            MembershipLogoLoop {
                BeatFinderPlusBrandMark(
                    width: horizontalSizeClass == .regular ? 220 : 172,
                    height: horizontalSizeClass == .regular ? 138 : 108,
                    strokeColor: .white,
                    foregroundColor: .white,
                    crownColor: Color(red: 0.54, green: 0.79, blue: 1.0),
                    lineWidth: horizontalSizeClass == .regular ? 3.2 : 2.8
                )
            }
        }
        .frame(height: horizontalSizeClass == .regular ? 250 : 210)
    }

    private var membershipDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Included")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))

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
            .padding(18)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            LiquidGlassButton(action: purchaseOrClose, cornerRadius: 20, fillOpacity: 0.12) {
                HStack {
                    Text(appState.subscription.accessLevel == .goPlus ? "Manage Subscription" : "Activate Membership")
                        .font(.system(size: 16, weight: .bold))

                    if appState.subscription.activePurchaseProductID != nil || appState.subscription.isRestoring {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    PrimaryButton(title: "Redeem", systemImage: "ticket", kind: .dark) {
                        SKPaymentQueue.default().presentCodeRedemptionSheet()
                    }

                    PrimaryButton(title: "Close", systemImage: "xmark", kind: .outline) {
                        appState.dismissSubscription()
                    }
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Redeem", systemImage: "ticket", kind: .dark) {
                        SKPaymentQueue.default().presentCodeRedemptionSheet()
                    }

                    PrimaryButton(title: "Close", systemImage: "xmark", kind: .outline) {
                        appState.dismissSubscription()
                    }
                }
            }

            Button {
                BeatHaptics.tap()
                withAnimation(MotionTokens.mediumEase) {
                    appState.subscription.flowStep = .plans
                }
            } label: {
                Text("Back to Plans")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.64))
            }
            .buttonStyle(BeatPressableButtonStyle())

            if !appState.subscription.statusMessage.isEmpty {
                Text(appState.subscription.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private func purchaseOrClose() {
        if appState.subscription.accessLevel == .goPlus {
            if let manageURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                BeatHaptics.tap()
                openURL(manageURL)
            }
        } else {
            Task {
                await appState.buySelectedPlan()
            }
        }
    }

    private var displayTitle: String {
        guard let plan = viewModel.selectedPlan(in: appState.subscription) else {
            return "BeatFinder Plus"
        }

        let lowercasedID = plan.id.lowercased()
        return lowercasedID.contains("year") ? "Pro Plan" : "Producer Plan"
    }
}
