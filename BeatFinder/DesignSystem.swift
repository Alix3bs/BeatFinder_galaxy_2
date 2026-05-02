import SwiftUI
import UIKit

enum BeatColors {
    static let background = Color(red: 0, green: 0, blue: 0)
    static let surfacePrimary = Color(red: 0.043, green: 0.051, blue: 0.063)
    static let surfaceSecondary = Color(red: 0.067, green: 0.078, blue: 0.102)
    static let elevatedCard = Color(red: 0.082, green: 0.098, blue: 0.133)
    static let overlayBlack = Color.black.opacity(0.58)
    static let thinBorder = Color.white.opacity(0.07)
    static let strongBorder = Color.white.opacity(0.11)
    static let textPrimary = Color(red: 0.961, green: 0.969, blue: 0.984)
    static let textSecondary = Color(red: 0.667, green: 0.698, blue: 0.741)
    static let textTertiary = Color(red: 0.435, green: 0.467, blue: 0.510)
    // Portage purple (#9668F5) is the global app accent.
    static let accentBlue = Color(red: 150.0 / 255.0, green: 104.0 / 255.0, blue: 245.0 / 255.0)
    static let accentBlueStrong = Color(red: 132.0 / 255.0, green: 88.0 / 255.0, blue: 232.0 / 255.0)
    static let accentBlueText = Color(red: 20.0 / 255.0, green: 13.0 / 255.0, blue: 36.0 / 255.0)
    static let accentBlueGlow = Color(red: 150.0 / 255.0, green: 104.0 / 255.0, blue: 245.0 / 255.0).opacity(0.24)
    // Upload now uses the same Portage accent family as the rest of the app.
    static let uploadAccentBlue = accentBlue
    static let uploadAccentBlueStrong = accentBlueStrong
    static let uploadAccentBlueText = accentBlueText
    static let uploadAccentBlueGlow = accentBlueGlow
    static let subscriptionDeepNavy = Color(red: 0.027, green: 0.071, blue: 0.220)
    static let subscriptionRoyalBlue = Color(red: 106.0 / 255.0, green: 76.0 / 255.0, blue: 189.0 / 255.0)
    static let subscriptionGlowBlue = Color(red: 150.0 / 255.0, green: 104.0 / 255.0, blue: 245.0 / 255.0).opacity(0.28)
    static let positive = Color(red: 0.494, green: 0.851, blue: 0.553)
    static let danger = Color(red: 1.0, green: 0.302, blue: 0.310)
}

enum BeatLayout {
    static let screenHorizontal: CGFloat = 18
    static let sectionSpacing: CGFloat = 16
    static let sectionSpacingTight: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 14
    static let iconButtonSize: CGFloat = 44
    static let minimumButtonHeight: CGFloat = 48
    static let compactContentMaxWidth: CGFloat = 440
    static let standardContentMaxWidth: CGFloat = 640
    static let wideContentMaxWidth: CGFloat = 760
    static let modalContentMaxWidth: CGFloat = 680

    static func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width >= 768 {
            return 36
        }
        return screenHorizontal
    }

    static func maxContentWidth(for width: CGFloat, style: BeatContentWidthStyle) -> CGFloat {
        switch style {
        case .compact:
            return width >= 768 ? compactContentMaxWidth : .infinity
        case .standard:
            return width >= 768 ? standardContentMaxWidth : .infinity
        case .wide:
            return width >= 768 ? wideContentMaxWidth : .infinity
        case .full:
            return .infinity
        }
    }

    static func floatingTabBarMaxWidth(for width: CGFloat) -> CGFloat {
        let horizontalPadding = horizontalPadding(for: width)
        let availableWidth = max(0, width - (horizontalPadding * 2))

        if width >= 768 {
            return min(availableWidth, 520)
        }

        return availableWidth
    }

    static func bottomContentPadding(
        safeBottom: CGFloat,
        tabBarClearance: CGFloat = 0,
        includeTabBarClearance: Bool = false,
        base: CGFloat = 24
    ) -> CGFloat {
        let accessoryClearance = includeTabBarClearance
            ? max(tabBarClearance + 8, safeBottom + 24)
            : max(safeBottom + 16, 16)

        return base + accessoryClearance
    }
}

enum BeatContentWidthStyle {
    case compact
    case standard
    case wide
    case full
}

private struct TabBarClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Additional bottom clearance needed to avoid the custom floating tab bar.
    var tabBarClearance: CGFloat {
        get { self[TabBarClearanceKey.self] }
        set { self[TabBarClearanceKey.self] = newValue }
    }
}

enum BeatTypography {
    static let screenTitle = Font.system(size: 34, weight: .bold)
    static let sectionTitle = Font.system(size: 18, weight: .bold)
    static let body = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 12, weight: .semibold)
}

enum BeatHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct BeatPressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98
    var pressedOpacity: Double = 0.88

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, pressedScale: pressedScale, pressedOpacity: pressedOpacity)
    }

    private struct PressableBody: View {
        let configuration: Configuration
        let pressedScale: CGFloat
        let pressedOpacity: Double

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? pressedScale : 1)
                .opacity(isEnabled ? (configuration.isPressed ? pressedOpacity : 1) : 0.56)
                .animation(MotionTokens.fastEase, value: configuration.isPressed)
                .animation(MotionTokens.fastEase, value: isEnabled)
        }
    }
}

struct PlaceholderDestination: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    var detail: String? = nil
    var systemImage: String = "sparkles.rectangle.stack"
    var buttonTitle: String = "OK"
}

struct PlaceholderDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let destination: PlaceholderDestination
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ScreenContainer(
            spacing: 20,
            topPadding: 14,
            bottomPadding: 24,
            maxWidthStyle: .compact
        ) {
            Color.black
        } content: {
            HStack {
                Spacer()

                Button {
                    BeatHaptics.tap()
                    dismissView()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(BeatPressableButtonStyle())
            }

            SectionCard(cornerRadius: 28, padding: 22, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)

                    Text(destination.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    Text(destination.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))

                    if let detail = destination.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))
                    }
                }
            }

            PrimaryButton(title: destination.buttonTitle) {
                dismissView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func dismissView() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

enum PrimaryButtonKind {
    case light
    case dark
    case outline
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: PrimaryButtonKind = .light
    var minHeight: CGFloat = BeatLayout.minimumButtonHeight
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            BeatHaptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: max(44, minHeight))
            .background(background)
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
        .opacity(isEnabled ? 1 : 0.68)
    }

    private var background: some View {
        switch kind {
        case .light:
            return AnyView(Color.white.opacity(0.94))
        case .dark:
            return AnyView(Color.white.opacity(0.10))
        case .outline:
            return AnyView(Color.black.opacity(0.35))
        }
    }

    private var foreground: Color {
        switch kind {
        case .light:
            return .black
        case .dark, .outline:
            return .white
        }
    }
}

struct SectionCard<Content: View>: View {
    var cornerRadius: CGFloat = BeatLayout.cornerRadius
    var padding: CGFloat = BeatLayout.cardPadding
    var fill: Color = Color.white.opacity(0.06)
    var strokeOpacity: Double = 0.12
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BeatLayout.sectionSpacingTight) {
            content
        }
        .padding(padding)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
        )
    }
}

struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var systemImage: String? = nil
    var titleColor: Color = .white
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(titleColor)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BeatTypography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 8)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(minHeight: 44)
    }
}

struct ScreenContainer<Background: View, Content: View>: View {
    var horizontalPadding: CGFloat = BeatLayout.screenHorizontal
    var spacing: CGFloat = BeatLayout.sectionSpacing
    var topPadding: CGFloat = 8
    var bottomPadding: CGFloat = 24
    var showsIndicators: Bool = false
    var maxWidthStyle: BeatContentWidthStyle = .full
    var includeTabBarClearance: Bool = false
    var fillsAvailableHeight: Bool = true
    var scrollToTopToken: Int = 0
    @ViewBuilder var background: () -> Background
    @ViewBuilder var content: () -> Content

    @Environment(\.tabBarClearance) private var tabBarClearance

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let resolvedHorizontalPadding = max(horizontalPadding, BeatLayout.horizontalPadding(for: proxy.size.width))
            let contentMaxWidth = BeatLayout.maxContentWidth(for: proxy.size.width, style: maxWidthStyle)
            let minimumHeight = max(0, proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - topPadding)
            let topAnchorID = "screen-container-top"

            ZStack {
                background().ignoresSafeArea()

                ScrollViewReader { reader in
                    ScrollView(showsIndicators: showsIndicators) {
                        VStack(alignment: .leading, spacing: spacing) {
                            Color.clear
                                .frame(height: 1)
                                .id(topAnchorID)

                            content()
                        }
                        .frame(maxWidth: contentMaxWidth, alignment: .leading)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: fillsAvailableHeight ? minimumHeight : nil,
                            alignment: .top
                        )
                        .padding(.horizontal, resolvedHorizontalPadding)
                        .padding(.top, topPadding)
                        .padding(
                            .bottom,
                            BeatLayout.bottomContentPadding(
                                safeBottom: safeBottom,
                                tabBarClearance: tabBarClearance,
                                includeTabBarClearance: includeTabBarClearance,
                                base: bottomPadding
                            )
                        )
                    }
                    .onChange(of: scrollToTopToken) { _, _ in
                        guard scrollToTopToken > 0 else { return }
                        withAnimation(MotionTokens.fastEase) {
                            reader.scrollTo(topAnchorID, anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

struct AppIconButton: View {
    let systemImage: String
    var foreground: Color = .white
    var background: Color = BeatColors.surfaceSecondary
    var action: () -> Void

    var body: some View {
        Button {
            BeatHaptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
    }
}
