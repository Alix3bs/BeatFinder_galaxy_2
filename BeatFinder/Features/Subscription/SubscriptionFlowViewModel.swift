import Foundation

@MainActor
final class SubscriptionFlowViewModel: ObservableObject {
    let benefits: [String] = [
        "Unlimited upload matching",
        "Faster result access",
        "Profile membership badge",
        "Priority creator tools"
    ]

    func selectedPlan(in state: SubscriptionState) -> SubscriptionPlan? {
        state.plans.first(where: { $0.id == state.selectedPlanID })
    }

    func title(for step: SubscriptionFlowStep) -> String {
        switch step {
        case .plans:
            return "Choose GO+"
        case .membership:
            return "Membership"
        }
    }
}
