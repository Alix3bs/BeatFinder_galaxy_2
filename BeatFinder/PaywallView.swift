import Combine
import CoreMotion
import Foundation

@MainActor
final class TiltMotionController: ObservableObject {
    struct Orientation: Equatable {
        var xDegrees: Double
        var yDegrees: Double

        static let zero = Orientation(xDegrees: 0, yDegrees: 0)
    }

    @Published private(set) var orientation: Orientation = .zero

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            orientation = Self.orientation(
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll
            )
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        orientation = .zero
    }

    static func orientation(
        pitch: Double,
        roll: Double,
        maxDegrees: Double = 7
    ) -> Orientation {
        let pitchDegrees = clamp((-pitch * 180 / .pi) * 0.42, maxDegrees: maxDegrees)
        let rollDegrees = clamp((roll * 180 / .pi) * 0.42, maxDegrees: maxDegrees)
        return Orientation(xDegrees: pitchDegrees, yDegrees: rollDegrees)
    }

    private static func clamp(_ value: Double, maxDegrees: Double) -> Double {
        min(max(value, -maxDegrees), maxDegrees)
    }
}
import SwiftUI

struct TiltCardView<Content: View>: View {
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: Content

    @StateObject private var motionController = TiltMotionController()

    var body: some View {
        content
            .rotation3DEffect(.degrees(motionController.orientation.xDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.75)
            .rotation3DEffect(.degrees(motionController.orientation.yDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
            .shadow(
                color: Color.black.opacity(0.18),
                radius: 14,
                x: CGFloat(motionController.orientation.yDegrees) * 0.3,
                y: 10 + CGFloat(abs(motionController.orientation.xDegrees)) * 0.25
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(MotionTokens.mediumEase, value: motionController.orientation)
            .onAppear {
                motionController.start()
            }
            .onDisappear {
                motionController.stop()
            }
    }
}
import SwiftUI

struct MembershipLogoLoop<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var animationStart = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(animationStart)
            let y = CGFloat(cos(elapsed * 1.62)) * 6
            let rotation = sin(elapsed * 1.54) * 2
            let scale = 1.015 + CGFloat(sin(elapsed * 1.78)) * 0.015

            content
                .offset(y: y)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
        }
        .onAppear {
            animationStart = Date()
        }
    }
}
import SwiftUI

private struct SubscriptionStageFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.black.opacity(0.20))
            )
    }
}
import SwiftUI

private struct SubscriptionFloatingCube: View {
    var body: some View {
        MembershipLogoLoop {
            BeatFinderSubscriptionLogoContainer(width: 150, height: 150)
        }
    }
}
import SwiftUI

private struct BeatFinderPlusWordmark: View {
    var scale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4 * scale) {
            Text("BeatFinder")
                .font(.system(size: 26 * scale, weight: .black))
                .foregroundStyle(.white)

            Text("Plus")
                .font(.system(size: 26 * scale, weight: .black))
                .foregroundStyle(BeatColors.accentBlueStrong)
        }
    }
}

private struct BeatFinderSubscriptionLogo: View {
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        Image("beatfinder_logo")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFill()
            .scaleEffect(1.12)
            .frame(width: width, height: height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: min(width, height) * 0.22,
                    style: .continuous
                )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 4)
    }
}

private struct BeatFinderSubscriptionLogoContainer: View {
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        BeatFinderSubscriptionLogo(width: width, height: height)
            .frame(width: width, height: height)
    }
}

private struct BeatFinderSubscriptionTitle: View {
    var body: some View {
        Text("BeatFinder Plus")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
    }
}
import SwiftUI

private struct SubscriptionLoopPattern: View {
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)

            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    let width = 168 + CGFloat(index * 18)
                    let height = 104 + CGFloat(index * 14)
                    let horizontal = CGFloat(sin(elapsed * 0.62 + Double(index) * 0.28)) * 10
                    let vertical = CGFloat(cos(elapsed * 0.44 + Double(index) * 0.26)) * 4

                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(index == 0 ? 0.16 : 0.07), lineWidth: 1)
                        .frame(width: width, height: height)
                        .offset(x: horizontal, y: vertical)
                }
            }
        }
        .onAppear {
            startDate = Date()
        }
    }
}
import SwiftUI

private struct MembershipStarField: View {
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(startDate)

                for index in 0..<20 {
                    let xSeed = normalizedHash(Double(index) * 18.231)
                    let ySeed = normalizedHash(Double(index) * 49.719)
                    let x = xSeed * size.width
                    let y = ySeed * size.height
                    let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(time * 0.18 + Double(index) * 0.7))
                    let radius: CGFloat = index.isMultiple(of: 9) ? 1.6 : 0.9
                    let opacity = index.isMultiple(of: 9) ? 0.20 : 0.08

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(Color.white.opacity(opacity * twinkle))
                    )
                }
            }
        }
        .onAppear {
            startDate = Date()
        }
    }

    private func normalizedHash(_ input: Double) -> CGFloat {
        CGFloat(abs(sin(input) * 18_731.131).truncatingRemainder(dividingBy: 1))
    }
}
import SwiftUI

struct StarDotBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<130 {
                    let xSeed = normalizedHash(Double(index) * 12.9898)
                    let ySeed = normalizedHash(Double(index) * 78.233)
                    let x = xSeed * size.width
                    let y = ySeed * size.height
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 0.9 + Double(index)))
                    let radius: CGFloat = index.isMultiple(of: 11) ? 1.8 : 0.8
                    let opacity = index.isMultiple(of: 11) ? 0.55 : 0.18

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(Color.white.opacity(opacity * twinkle))
                    )
                }

                for lineIndex in 0..<16 {
                    let y = CGFloat(lineIndex) / 16 * size.height
                    let opacity = 0.02 + 0.01 * (0.5 + 0.5 * sin(time * 0.35 + Double(lineIndex)))
                    context.stroke(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 0)),
                        with: .color(Color.white.opacity(opacity)),
                        lineWidth: 0.6
                    )
                }
            }
        }
        .background(Color.black)
    }

    private func normalizedHash(_ input: Double) -> CGFloat {
        CGFloat(abs(sin(input) * 43_758.5453).truncatingRemainder(dividingBy: 1))
    }
}
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

    func displayPlanTitle(for plan: SubscriptionPlan?) -> String {
        guard let plan else { return "Selected Plan" }
        if plan.title.lowercased().contains("year") || plan.id.lowercased().contains("year") {
            return "Producer Plan"
        }
        return "Pro Plan"
    }

    func title(for step: SubscriptionFlowStep) -> String {
        switch step {
        case .plans:
            return "BeatFinder Plus"
        case .membership:
            return "BeatFinder Plus"
        }
    }
}

private enum SubscriptionDisplayPlanKind: String {
    case free
    case pro
    case producer

    static let freePlanID = "com.beatfinder.plan.free"

    static func from(plan: SubscriptionPlan?) -> SubscriptionDisplayPlanKind {
        guard let plan else { return .free }
        return from(id: plan.id)
    }

    static func from(id: String?) -> SubscriptionDisplayPlanKind {
        let identifier = (id ?? "").lowercased()
        if identifier.contains("free") {
            return .free
        }
        if identifier.contains("year") || identifier.contains("producer") {
            return .producer
        }
        return .pro
    }

    var title: String {
        switch self {
        case .free:
            return "Free Plan"
        case .pro:
            return "Pro Plan"
        case .producer:
            return "Producer Plan"
        }
    }

    var subtitle: String {
        switch self {
        case .free:
            return "Default access"
        case .pro:
            return "Monthly membership"
        case .producer:
            return "Yearly membership"
        }
    }

    var price: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "$9.99"
        case .producer:
            return "$79.99"
        }
    }

    var chooserPreview: String {
        switch self {
        case .free:
            return "Basic beat discovery • Limited saved beats"
        case .pro:
            return "Unlimited saved beats • Faster match tools"
        case .producer:
            return "Everything in Pro • Early access features"
        }
    }

    var detailSubtitle: String {
        switch self {
        case .free:
            return "Free access"
        case .pro, .producer:
            return "BeatFinder Plus Membership"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Basic beat discovery",
                "Limited saved beats",
                "Standard creator profile",
                "Standard matching access"
            ]
        case .pro:
            return [
                "Unlimited saved beats",
                "Faster match tools",
                "Priority result actions",
                "Enhanced creator tools"
            ]
        case .producer:
            return [
                "Everything in Pro",
                "Producer badge",
                "Premium profile tools",
                "Early access features"
            ]
        }
    }

    var systemImage: String {
        switch self {
        case .free:
            return "sparkles"
        case .pro:
            return "waveform.badge.plus"
        case .producer:
            return "crown.fill"
        }
    }
}
import SwiftUI

struct SubscriptionPlanSelectionView: View {
    @EnvironmentObject private var appState: AppState
    let viewModel: SubscriptionFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                BeatFinderPlusWordmark(scale: 1.04)

                Text("Choose your membership plan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BeatColors.textPrimary)

                Text("Pick a plan below to open the membership card and continue.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(orderedPlans.enumerated()), id: \.element.id) { index, plan in
                    let planKind = SubscriptionDisplayPlanKind.from(plan: plan)
                    Button {
                        BeatHaptics.tap()
                        appState.selectPlan(plan.id)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: planKind.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BeatColors.accentBlueText)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(planKind.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.black)

                                Text("\(planKind.subtitle) • \(planKind.price)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.58))

                                Text(planKind.chooserPreview)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.46))
                                    .lineLimit(2)
                            }

                            Spacer()

                            if appState.subscription.selectedPlanID == plan.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(BeatColors.accentBlueStrong)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.34))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.98))
                    }
                    .buttonStyle(BeatPressableButtonStyle())

                    if index < orderedPlans.count - 1 {
                        Divider()
                            .overlay(Color.black.opacity(0.08))
                            .padding(.leading, 60)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            if orderedPlans.isEmpty, case .failed(let message) = appState.subscription.loadState {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            Button {
                BeatHaptics.tap()
                Task {
                    await appState.restorePurchases()
                }
            } label: {
                HStack(spacing: 8) {
                    if appState.subscription.isRestoring {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(appState.subscription.isRestoring ? "Restoring..." : "Restore purchases")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BeatColors.textPrimary.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BeatPressableButtonStyle())
            .disabled(appState.subscription.isRestoring)
        }
    }

    private var orderedPlans: [SubscriptionPlan] {
        let freePlan = SubscriptionPlan(
            id: SubscriptionDisplayPlanKind.freePlanID,
            title: "Free",
            subtitle: "Default access",
            priceText: "Free",
            badge: nil
        )

        let paidPlans = appState.subscription.plans
            .filter { SubscriptionDisplayPlanKind.from(plan: $0) != .free }
            .sorted { lhs, rhs in
            rank(for: lhs) < rank(for: rhs)
        }

        return [freePlan] + paidPlans
    }

    private func rank(for plan: SubscriptionPlan) -> Int {
        let planKind = SubscriptionDisplayPlanKind.from(plan: plan)
        switch planKind {
        case .pro:
            return 0
        case .producer:
            return 1
        case .free:
            return -1
        }
    }
}
import SwiftUI

struct MembershipView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    let viewModel: SubscriptionFlowViewModel

    var body: some View {
        let selectedPlan = viewModel.selectedPlan(in: appState.subscription)
        let planKind = SubscriptionDisplayPlanKind.from(id: appState.subscription.selectedPlanID ?? selectedPlan?.id)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                BeatFinderPlusWordmark(scale: 1.05)

                Text(planKind.detailSubtitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BeatColors.textPrimary)

                Text("Review your selected plan and continue when you’re ready.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            TiltCardView(cornerRadius: 30) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black,
                                    Color(red: 0.043, green: 0.051, blue: 0.063),
                                    Color(red: 0.067, green: 0.086, blue: 0.173)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    MembershipStarField()
                        .opacity(0.16)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                    Circle()
                        .fill(BeatColors.subscriptionGlowBlue)
                        .frame(width: horizontalSizeClass == .regular ? 220 : 180, height: horizontalSizeClass == .regular ? 220 : 180)
                        .blur(radius: 76)
                        .offset(y: 56)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(statusText(for: planKind))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(BeatColors.textPrimary.opacity(0.78))

                                Text(planKind.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(planKind.price)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(BeatColors.textPrimary.opacity(0.82))
                            }

                            Spacer()
                        }

                        HStack {
                            Spacer()

                            MembershipLogoLoop {
                                BeatFinderSubscriptionLogo(
                                    width: horizontalSizeClass == .regular ? 232 : 188,
                                    height: horizontalSizeClass == .regular ? 232 : 188
                                )
                            }

                            Spacer()
                        }
                        .padding(.vertical, 10)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                ForEach(planKind.features, id: \.self) { feature in
                                    benefitCapsule(feature)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(planKind.features, id: \.self) { feature in
                                    benefitCapsule(feature)
                                }
                            }
                        }
                    }
                    .padding(horizontalSizeClass == .regular ? 26 : 22)
                }
                .frame(height: horizontalSizeClass == .regular ? 348 : 308)
            }

            if !appState.subscription.statusMessage.isEmpty {
                Text(appState.subscription.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 12) {
                Button {
                    BeatHaptics.tap()
                    withAnimation(MotionTokens.mediumEase) {
                        appState.subscription.flowStep = .plans
                    }
                } label: {
                    Text("Back")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BeatColors.textSecondary)
                }
                .buttonStyle(BeatPressableButtonStyle())

                Spacer()

                Button {
                    BeatHaptics.tap()
                    Task {
                        await appState.restorePurchases()
                    }
                } label: {
                    Text("Redeem")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BeatColors.textPrimary.opacity(0.9))
                }
                .buttonStyle(BeatPressableButtonStyle())

                Button {
                    manageMembership(for: planKind)
                } label: {
                    HStack(spacing: 8) {
                        Text(primaryActionTitle(for: planKind))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(BeatColors.accentBlueText)

                        if planKind != .free && (appState.subscription.activePurchaseProductID != nil || appState.subscription.isRestoring) {
                            ProgressView()
                                .tint(BeatColors.accentBlueText)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(BeatColors.accentBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(BeatPressableButtonStyle())
            }
        }
    }

    private func manageMembership(for planKind: SubscriptionDisplayPlanKind) {
        if planKind == .free {
            BeatHaptics.tap()
            appState.dismissSubscription()
            return
        }

        if appState.subscription.accessLevel == .goPlus {
            BeatHaptics.tap()
            if let manageURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                openURL(manageURL)
            }
        } else {
            Task {
                await appState.buySelectedPlan()
            }
        }
    }

    private func statusText(for planKind: SubscriptionDisplayPlanKind) -> String {
        if planKind == .free {
            return appState.subscription.accessLevel == .free ? "Current access" : "Free access"
        }
        return appState.subscription.accessLevel == .goPlus ? "Membership Active" : "Ready to Activate"
    }

    private func primaryActionTitle(for planKind: SubscriptionDisplayPlanKind) -> String {
        if planKind == .free {
            return appState.subscription.accessLevel == .free ? "Current Plan" : "Continue"
        }
        return "Activate"
    }

    private func benefitCapsule(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(BeatColors.textPrimary.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }
}
import SwiftUI

struct SubscriptionFlowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = SubscriptionFlowViewModel()

    var embeddedPresentation: Bool = false
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BeatColors.surfacePrimary,
                            Color(red: 0.031, green: 0.055, blue: 0.141).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(BeatColors.subscriptionGlowBlue)
                .frame(width: horizontalSizeClass == .regular ? 280 : 220, height: horizontalSizeClass == .regular ? 280 : 220)
                .blur(radius: 64)
                .offset(y: appState.subscription.flowStep == .plans ? -80 : 64)

            MembershipStarField()
                .opacity(0.18)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    closeButton
                }

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
            .padding(horizontalSizeClass == .regular ? 24 : 20)
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 560 : 420)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.34), radius: 28, x: 0, y: 18)
        .task {
            if case .idle = appState.subscription.loadState {
                await appState.subscriptionManager.loadProducts()
                appState.refreshSnapshots()
            }

            if appState.subscription.accessLevel == .free {
                appState.subscription.selectedPlanID = SubscriptionDisplayPlanKind.freePlanID
            }
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(BeatColors.surfaceSecondary)
                .clipShape(Circle())
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
}
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SubscriptionFlowView(embeddedPresentation: true, onClose: {
            dismiss()
        })
        .environmentObject(appState)
    }
}
