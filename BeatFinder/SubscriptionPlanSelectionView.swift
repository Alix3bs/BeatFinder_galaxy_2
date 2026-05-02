import SwiftUI

struct SubscriptionPlanSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let viewModel: SubscriptionFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick the plan that matches how often you upload and preview results.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))

            LazyVGrid(columns: planColumns, spacing: 12) {
                ForEach(appState.subscription.plans) { plan in
                    Button {
                        BeatHaptics.tap()
                        appState.selectPlan(plan.id)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(displayTitle(for: plan))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white)

                                    if let badge = plan.badge {
                                        Text(badge)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.14))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(plan.subtitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.62))
                            }

                            Spacer()

                            Text(plan.priceText)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(appState.subscription.selectedPlanID == plan.id ? 0.12 : 0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    appState.subscription.selectedPlanID == plan.id
                                        ? Color(red: 0.54, green: 0.79, blue: 1.0).opacity(0.7)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }
            }

            PrimaryButton(
                title: appState.subscription.isRestoring ? "Restoring..." : "Restore Purchases",
                systemImage: "arrow.clockwise",
                kind: .outline
            ) {
                Task {
                    await appState.restorePurchases()
                }
            }
            .disabled(appState.subscription.isRestoring)

            if case .failed(let message) = appState.subscription.loadState {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private var planColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible())]
    }

    private func displayTitle(for plan: SubscriptionPlan) -> String {
        let lowercasedID = plan.id.lowercased()
        return lowercasedID.contains("year") ? "Pro Plan" : "Producer Plan"
    }
}
