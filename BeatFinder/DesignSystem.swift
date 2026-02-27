import SwiftUI

enum BeatLayout {
    static let screenHorizontal: CGFloat = 18
    static let sectionSpacing: CGFloat = 16
    static let sectionSpacingTight: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 14
    static let iconButtonSize: CGFloat = 44
    static let minimumButtonHeight: CGFloat = 48
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
    static let sectionTitle = Font.system(size: 20, weight: .bold)
    static let body = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .semibold)
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

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
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
    @ViewBuilder var background: () -> Background
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            ZStack {
                background().ignoresSafeArea()

                ScrollView(showsIndicators: showsIndicators) {
                    VStack(alignment: .leading, spacing: spacing) {
                        content()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding + max(14, safeBottom))
                }
            }
        }
    }
}

struct AppIconButton: View {
    let systemImage: String
    var foreground: Color = .white
    var background: Color = Color.white.opacity(0.08)
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
