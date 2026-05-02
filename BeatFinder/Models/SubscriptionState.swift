import Foundation

struct SubscriptionPlan: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let priceText: String
    let badge: String?
}

struct SubscriptionState: Equatable {
    enum AccessLevel: Equatable {
        case free
        case goPlus
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var accessLevel: AccessLevel = .free
    var plans: [SubscriptionPlan] = []
    var selectedPlanID: String?
    var flowStep: SubscriptionFlowStep = .plans
    var isPresented: Bool = false
    var loadState: LoadState = .idle
    var isRestoring: Bool = false
    var activePurchaseProductID: String?
    var statusMessage: String = ""
}
