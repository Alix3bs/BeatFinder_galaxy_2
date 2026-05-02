import Combine
import Foundation
import StoreKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var session = SessionState(
        userID: nil,
        displayName: "",
        username: "",
        avatarURL: nil,
        isVerified: false
    )
    @Published var subscription = SubscriptionState()
    @Published var homePath: [HomeRoute] = []
    @Published var uploadPath: [UploadRoute] = []
    @Published var profilePath: [ProfileRoute] = []
    @Published var safePath: [SafeRoute] = []

    let authStore: AuthStore
    let subscriptionManager: SubscriptionManager

    private let isUITestAuthenticated: Bool
    private var avatarTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        authStore: AuthStore? = nil,
        subscriptionManager: SubscriptionManager? = nil
    ) {
        self.authStore = authStore ?? AuthStore()
        self.subscriptionManager = subscriptionManager ?? SubscriptionManager()
        self.isUITestAuthenticated = ProcessInfo.processInfo.arguments.contains("--uitesting-authenticated")

        if isUITestAuthenticated {
            session = SessionState(
                userID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
                displayName: "Tray3Beats",
                username: "tray3beats",
                avatarURL: nil,
                isVerified: true
            )
            subscription = SubscriptionState(
                accessLevel: .free,
                plans: Self.previewPlans,
                selectedPlanID: Self.previewPlans.first?.id,
                flowStep: .plans,
                isPresented: false,
                loadState: .loaded,
                isRestoring: false,
                activePurchaseProductID: nil,
                statusMessage: ""
            )
        } else {
            bindAuth()
            bindSubscription()
            refreshSnapshots()
        }
    }

    func bootstrap() async {
        guard !isUITestAuthenticated else { return }
        await authStore.bootstrap()
        await subscriptionManager.loadProducts()
        await subscriptionManager.refreshEntitlements()
        refreshSnapshots()
    }

    func presentSubscription(step: SubscriptionFlowStep = .plans) {
        if subscription.selectedPlanID == nil {
            subscription.selectedPlanID = subscription.plans.first?.id
        }
        subscription.flowStep = step
        withAnimation(MotionTokens.topModalSpring) {
            subscription.isPresented = true
        }
    }

    func dismissSubscription() {
        withAnimation(MotionTokens.mediumEase) {
            subscription.isPresented = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(MotionTokens.mediumDuration * 1_000)))
            guard !subscription.isPresented else { return }
            subscription.flowStep = .plans
        }
    }

    func selectPlan(_ planID: String) {
        subscription.selectedPlanID = planID
        withAnimation(MotionTokens.mediumEase) {
            subscription.flowStep = .membership
        }
    }

    func openUploadResult(_ result: BeatResultModel) {
        selectedTab = .upload
        uploadPath = [.result(result)]
    }

    func openSettings() {
        selectedTab = .profile
        profilePath = [.settings]
    }

    func openWallet() {
        selectedTab = .profile
        profilePath = [.settings, .wallet]
    }

    func buySelectedPlan() async {
        guard !isUITestAuthenticated else {
            subscription.accessLevel = .goPlus
            subscription.statusMessage = "Preview purchase successful."
            return
        }

        guard let selectedPlanID = subscription.selectedPlanID,
              let product = subscriptionManager.products.first(where: { $0.id == selectedPlanID })
        else {
            return
        }

        await subscriptionManager.buy(product)
        refreshSnapshots()
    }

    func restorePurchases() async {
        guard !isUITestAuthenticated else {
            subscription.statusMessage = "Preview mode does not restore purchases."
            return
        }

        await subscriptionManager.restore()
        refreshSnapshots()
    }

    func refreshSnapshots() {
        guard !isUITestAuthenticated else { return }
        syncSessionFromAuth()
        syncSubscriptionFromManager()
    }
}

private extension AppState {
    static let previewPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "com.beatfinder.pro.monthly",
            title: "Monthly",
            subtitle: "Flexible access billed every month",
            priceText: "$9.99",
            badge: nil
        ),
        SubscriptionPlan(
            id: "com.beatfinder.pro.yearly",
            title: "Yearly",
            subtitle: "Best for creators staying active",
            priceText: "$79.99",
            badge: "Best Value"
        )
    ]

    func bindAuth() {
        authStore.$sessionUserId
            .combineLatest(authStore.$profile)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.syncSessionFromAuth()
            }
            .store(in: &cancellables)
    }

    func bindSubscription() {
        subscriptionManager.$products
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncSubscriptionFromManager()
            }
            .store(in: &cancellables)

        subscriptionManager.$isPro
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncSubscriptionFromManager()
            }
            .store(in: &cancellables)

        subscriptionManager.$statusText
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncSubscriptionFromManager()
            }
            .store(in: &cancellables)

        subscriptionManager.$productsLoadState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncSubscriptionFromManager()
            }
            .store(in: &cancellables)

        subscriptionManager.$isRestoring
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncSubscriptionFromManager()
            }
            .store(in: &cancellables)

        subscriptionManager.$activePurchaseProductID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncSubscriptionFromManager()
            }
            .store(in: &cancellables)
    }

    func syncSessionFromAuth() {
        let trimmedUsername = authStore.profile?.username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let username = (trimmedUsername?.isEmpty == false ? trimmedUsername : nil) ?? "beatfinder"

        session.userID = authStore.sessionUserId
        session.username = username
        session.displayName = username
        session.isVerified = authStore.profile?.verified ?? false

        avatarTask?.cancel()
        session.avatarURL = nil

        guard authStore.sessionUserId != nil else {
            resetNavigationOnSignOut()
            return
        }

        avatarTask = Task { [weak self] in
            guard let self else { return }
            let avatarURL = await authStore.signedAvatarURL()
            guard !Task.isCancelled else { return }
            self.session.avatarURL = avatarURL
        }
    }

    func syncSubscriptionFromManager() {
        let mappedPlans = subscriptionManager.products.map(Self.mapPlan)

        subscription.plans = mappedPlans.isEmpty ? Self.previewPlansIfNeeded(for: subscriptionManager.productsLoadState) : mappedPlans
        subscription.selectedPlanID = Self.resolveSelectedPlanID(
            current: subscription.selectedPlanID,
            plans: subscription.plans
        )
        subscription.accessLevel = subscriptionManager.isPro ? .goPlus : .free
        subscription.loadState = Self.mapLoadState(subscriptionManager.productsLoadState)
        subscription.isRestoring = subscriptionManager.isRestoring
        subscription.activePurchaseProductID = subscriptionManager.activePurchaseProductID
        subscription.statusMessage = subscriptionManager.statusText
    }

    func resetNavigationOnSignOut() {
        selectedTab = .home
        homePath = []
        uploadPath = []
        profilePath = []
        safePath = []
        dismissSubscription()
    }

    static func resolveSelectedPlanID(current: String?, plans: [SubscriptionPlan]) -> String? {
        if let current, plans.contains(where: { $0.id == current }) {
            return current
        }
        return plans.first?.id
    }

    static func mapLoadState(_ state: SubscriptionManager.ProductsLoadState) -> SubscriptionState.LoadState {
        switch state {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded:
            return .loaded
        case .failed(let message):
            return .failed(message)
        }
    }

    static func mapPlan(_ product: Product) -> SubscriptionPlan {
        let lowercasedID = product.id.lowercased()
        let title: String
        let subtitle: String
        let badge: String?

        if lowercasedID.contains("year") {
            title = "Yearly"
            subtitle = "Best for creators staying active"
            badge = "Best Value"
        } else {
            title = "Monthly"
            subtitle = "Flexible access billed every month"
            badge = nil
        }

        return SubscriptionPlan(
            id: product.id,
            title: title,
            subtitle: subtitle,
            priceText: product.displayPrice,
            badge: badge
        )
    }

    static func previewPlansIfNeeded(for state: SubscriptionManager.ProductsLoadState) -> [SubscriptionPlan] {
        switch state {
        case .failed, .idle, .loading:
            return previewPlans
        case .loaded:
            return []
        }
    }
}
