import Foundation

enum AppTab: Hashable {
    case home
    case upload
    case profile
    case safe
}

enum HomeRoute: Hashable {
    case search
    case beatDetail(BeatResultModel)
    case mondayReleases([BeatResultModel])
    case placeholder(PlaceholderDestination)
}

enum UploadRoute: Hashable {
    case result(BeatResultModel)
}

enum ProfileRoute: Hashable {
    case settings
    case wallet
}

enum SafeRoute: Hashable {}

enum SubscriptionFlowStep: Hashable {
    case plans
    case membership
}
import SwiftUI

enum MotionTokens {
    static let fastDuration: Double = 0.12
    static let mediumDuration: Double = 0.32
    static let slowDuration: Double = 0.4
    static let maxTiltDegrees: Double = 7

    static let fastEase: Animation = .easeInOut(duration: fastDuration)
    static let mediumEase: Animation = .easeInOut(duration: mediumDuration)
    static let slowEase: Animation = .easeInOut(duration: slowDuration)
    static let topModalSpring: Animation = .interactiveSpring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.16)
}
import Foundation

struct SessionState: Equatable {
    var userID: UUID?
    var displayName: String
    var username: String
    var avatarURL: URL?
    var isVerified: Bool

    var isAuthenticated: Bool { userID != nil }
}
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
import SwiftUI

private struct LiquidGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let strokeOpacity: Double
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(fillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.35),
                                Color.white.opacity(strokeOpacity * 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 12, x: 0, y: 8)
    }
}

extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat = 24,
        fillOpacity: Double = 0.06,
        strokeOpacity: Double = 0.16,
        shadowOpacity: Double = 0.24
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                strokeOpacity: strokeOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }
}

struct LiquidGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var contentPadding: CGFloat = 18
    var fillOpacity: Double = 0.06
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BeatLayout.sectionSpacingTight) {
            content
        }
        .padding(contentPadding)
        .liquidGlassSurface(cornerRadius: cornerRadius, fillOpacity: fillOpacity)
    }
}
import SwiftUI

struct LiquidGlassButton<Label: View>: View {
    let action: () -> Void
    var cornerRadius: CGFloat = 18
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 14
    var fillOpacity: Double = 0.08
    var foregroundStyle: AnyShapeStyle = AnyShapeStyle(Color.white)
    @ViewBuilder var label: () -> Label

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .foregroundStyle(foregroundStyle)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.985 : 1)
        .animation(MotionTokens.fastEase, value: isPressed)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
        )
        .liquidGlassSurface(cornerRadius: cornerRadius, fillOpacity: fillOpacity, strokeOpacity: 0.18, shadowOpacity: 0.2)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}
import SwiftUI

struct BeatFinderPlusBrandMark: View {
    var width: CGFloat = 92
    var height: CGFloat = 58
    var strokeColor: Color = .white
    var foregroundColor: Color = .white
    var crownColor: Color = .white
    var lineWidth: CGFloat = 2.4

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: height * 0.48, style: .continuous)
                .stroke(strokeColor.opacity(0.92), lineWidth: lineWidth)
                .background(
                    RoundedRectangle(cornerRadius: height * 0.48, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )

            HStack(spacing: 0) {
                Text("B")
                    .font(.system(size: height * 0.52, weight: .black, design: .serif))
                    .tracking(-2.2)

                Text("F")
                    .font(.system(size: height * 0.50, weight: .black, design: .serif))
                    .tracking(-1.4)
            }
            .foregroundStyle(foregroundColor)

            Image(systemName: "crown.fill")
                .font(.system(size: height * 0.23, weight: .bold))
                .foregroundStyle(crownColor)
                .offset(x: height * 0.10, y: -height * 0.16)
        }
        .frame(width: width, height: height)
    }
}

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
            let isPad = proxy.size.width >= 768
            let maxWidth = isPad ? min(600, proxy.size.width - 96) : max(0, proxy.size.width - 48)
            let horizontalPadding: CGFloat = 24
            let verticalPadding: CGFloat = isPad ? 28 : max(proxy.safeAreaInsets.top + 24, 24)

            ZStack {
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
                        .frame(maxWidth: maxWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .scaleEffect(isPresented ? 1 : 0.96)
                        .opacity(isPresented ? 1 : 0)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .accessibilityIdentifier("subscriptionModal")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        if subscription.accessLevel == .free {
            subscription.selectedPlanID = Self.freePlan.id
        } else if subscription.selectedPlanID == nil || subscription.selectedPlanID == Self.freePlan.id {
            subscription.selectedPlanID = subscription.plans.first(where: { $0.id != Self.freePlan.id })?.id
                ?? subscription.plans.first?.id
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
    static let freePlan = SubscriptionPlan(
        id: "com.beatfinder.plan.free",
        title: "Free",
        subtitle: "Default access",
        priceText: "Free",
        badge: nil
    )

    static let previewPlans: [SubscriptionPlan] = [
        freePlan,
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
        let mappedPlans = subscriptionManager.products
            .map(Self.mapPlan)
            .sorted(by: Self.planSortOrder)

        subscription.plans = mappedPlans.isEmpty
            ? Self.previewPlansIfNeeded(for: subscriptionManager.productsLoadState)
            : [Self.freePlan] + mappedPlans
        subscription.selectedPlanID = Self.resolveSelectedPlanID(
            current: subscription.selectedPlanID,
            plans: subscription.plans
        )
        subscription.accessLevel = subscriptionManager.isPro ? .goPlus : .free
        if subscription.accessLevel == .goPlus, subscription.selectedPlanID == Self.freePlan.id {
            subscription.selectedPlanID = subscription.plans.first(where: { $0.id != Self.freePlan.id })?.id
        }
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

    static func planSortOrder(_ lhs: SubscriptionPlan, _ rhs: SubscriptionPlan) -> Bool {
        sortRank(for: lhs) < sortRank(for: rhs)
    }

    static func sortRank(for plan: SubscriptionPlan) -> Int {
        let lowercasedID = plan.id.lowercased()
        if lowercasedID.contains("free") {
            return 0
        }
        if lowercasedID.contains("month") {
            return 1
        }
        if lowercasedID.contains("year") {
            return 2
        }
        return 3
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
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var savedMatches: SavedMatchesStore
    @State private var hasBootstrapped = false
    @State private var showLaunchOverlay = true

    var body: some View {
        ZStack {
            Group {
                if appState.session.isAuthenticated {
                    ContentView()
                } else {
                    GalaxyEntryView()
                        .environmentObject(appState.authStore)
                }
            }

            GlassModalSheet(
                isPresented: Binding(
                    get: { appState.session.isAuthenticated && appState.subscription.isPresented },
                    set: { isPresented in
                        if !isPresented {
                            appState.dismissSubscription()
                        }
                    }
                )
            ) {
                SubscriptionFlowView()
                    .environmentObject(appState)
            }
            .zIndex(2)

            if showLaunchOverlay {
                LaunchFlowView {
                    withAnimation(.easeOut(duration: 0.22)) {
                        showLaunchOverlay = false
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true
            await appState.bootstrap()
            await savedMatches.syncFromRemote(userId: appState.session.userID)
        }
        .onChange(of: appState.session.userID) { _, userID in
            Task {
                await savedMatches.syncFromRemote(userId: userID)
            }
        }
        .preferredColorScheme(.dark)
    }
}
