import LocalAuthentication
import PhotosUI
import SwiftUI
import UserNotifications

private struct SettingsSectionModel: Identifiable {
    let id = UUID()
    let rows: [SettingsRowModel]
    var footer: String? = nil
}

private struct SettingsRowModel: Identifiable {
    enum Action: Hashable {
        case destination(SettingsDestination)
        case clearCache
        case signOut
    }

    let id = UUID()
    let title: String
    let systemImage: String
    var accentColor: Color = .white
    let action: Action
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var isClearCacheConfirmationPresented = false
    @State private var isSignOutConfirmationPresented = false
    @State private var isClearingCache = false
    @State private var isSigningOut = false
    @State private var feedbackMessage: String?

    private let sections: [SettingsSectionModel] = [
        SettingsSectionModel(rows: [
            SettingsRowModel(title: "Account", systemImage: "person", action: .destination(.account)),
            SettingsRowModel(
                title: "Verification",
                systemImage: "checkmark.seal",
                accentColor: BeatColors.accentBlue,
                action: .destination(.verification)
            ),
            SettingsRowModel(title: "Change Password", systemImage: "key.horizontal", action: .destination(.changePassword)),
            SettingsRowModel(title: "Liked Posts", systemImage: "rectangle.on.rectangle", action: .destination(.likedPosts))
        ]),
        SettingsSectionModel(rows: [
            SettingsRowModel(title: "Wallet", systemImage: "creditcard", action: .destination(.wallet)),
            SettingsRowModel(title: "Notifications", systemImage: "bell", action: .destination(.notifications)),
            SettingsRowModel(title: "Privacy", systemImage: "lock", action: .destination(.privacy)),
            SettingsRowModel(title: "Security", systemImage: "shield", action: .destination(.security)),
            SettingsRowModel(title: "Language", systemImage: "globe", action: .destination(.language)),
            SettingsRowModel(title: "Appearance", systemImage: "moon", action: .destination(.appearance))
        ]),
        SettingsSectionModel(rows: [
            SettingsRowModel(title: "Help Center", systemImage: "lifepreserver", action: .destination(.helpCenter)),
            SettingsRowModel(title: "Report a Problem", systemImage: "message", action: .destination(.reportProblem))
        ]),
        SettingsSectionModel(rows: [
            SettingsRowModel(title: "Terms of Use", systemImage: "doc.text", action: .destination(.termsOfUse)),
            SettingsRowModel(title: "Privacy Policy", systemImage: "doc.text.magnifyingglass", action: .destination(.privacyPolicy))
        ]),
        SettingsSectionModel(rows: [
            SettingsRowModel(title: "Join BeatFinder AI Testers", systemImage: "testtube.2", action: .destination(.bandlabTesters)),
            SettingsRowModel(
                title: "Backend API Test",
                systemImage: "antenna.radiowaves.left.and.right",
                accentColor: BeatColors.accentBlue,
                action: .destination(.backendApiTest)
            )
        ]),
        SettingsSectionModel(
            rows: [
                SettingsRowModel(title: "Clear App Cache", systemImage: "trash", action: .clearCache)
            ],
            footer: "Clear the app cache to free up memory on your device."
        )
    ]

    var body: some View {
        ScreenContainer(
            spacing: 22,
            topPadding: 12,
            bottomPadding: 40,
            maxWidthStyle: .standard,
            includeTabBarClearance: true
        ) {
            Color.black
        } content: {
            header

            ForEach(sections) { section in
                VStack(spacing: 0) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row)

                        if index < section.rows.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        .allowsHitTesting(false)
                )

                if let footer = section.footer {
                    Text(footer)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .padding(.top, -10)
                }
            }

            Button {
                BeatHaptics.tap()
                isSignOutConfirmationPresented = true
            } label: {
                Text(isSigningOut ? "Signing Out..." : "Sign out")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
            }
            .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))

            Text("Version 11.17.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .settingsToast(message: $feedbackMessage)
        .confirmationDialog("Clear app cache?", isPresented: $isClearCacheConfirmationPresented, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button(isClearingCache ? "Clearing..." : "Clear Cache", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This removes temporary files and local cached assets. Your account and saved data will stay intact.")
        }
        .confirmationDialog("Sign out?", isPresented: $isSignOutConfirmationPresented, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button(isSigningOut ? "Signing Out..." : "Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("You’ll need to sign back in to access your account.")
        }
    }

    private var header: some View {
        HStack {
            Button {
                BeatHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))

            Spacer()

            Text("Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 42, height: 42)
        }
    }

    @ViewBuilder
    private func rowView(_ row: SettingsRowModel) -> some View {
        switch row.action {
        case .destination(let destination):
            NavigationLink {
                settingsDestinationView(for: destination)
            } label: {
                settingsRowContent(row)
            }
            .contentShape(Rectangle())
            .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))
            .simultaneousGesture(
                TapGesture().onEnded {
                    BeatHaptics.tap()
                }
            )
            .accessibilityIdentifier("settings.\(row.title.replacingOccurrences(of: " ", with: "").lowercased())")

        case .clearCache:
            Button {
                BeatHaptics.tap()
                isClearCacheConfirmationPresented = true
            } label: {
                settingsRowContent(row)
            }
            .contentShape(Rectangle())
            .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))

        case .signOut:
            Button {
                BeatHaptics.tap()
                isSignOutConfirmationPresented = true
            } label: {
                settingsRowContent(row)
            }
            .contentShape(Rectangle())
            .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))
        }
    }

    private func settingsRowContent(_ row: SettingsRowModel) -> some View {
        HStack(spacing: 14) {
            Image(systemName: row.systemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(row.accentColor)
                .frame(width: 26)

            Text(row.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.37, green: 0.43, blue: 0.56))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func settingsDestinationView(for destination: SettingsDestination) -> some View {
        switch destination {
        case .account:
            AccountSettingsView()
        case .verification:
            VerificationSettingsView()
        case .changePassword:
            ChangePasswordSettingsView()
        case .linkedAccounts:
            LinkedAccountsSettingsView()
        case .likedPosts:
            LikedPostsSettingsView()
        case .wallet:
            WalletView()
        case .notifications:
            NotificationsSettingsView()
        case .privacy:
            PrivacySettingsView()
        case .security:
            SecuritySettingsView()
        case .language:
            LanguageSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .screenCapturing:
            ScreenCapturingSettingsView()
        case .helpCenter:
            HelpCenterSettingsView()
        case .reportProblem:
            ReportProblemSettingsView()
        case .termsOfUse:
            LegalDocumentSettingsView(
                title: "Terms of Use",
                content: Self.termsOfUseText
            )
        case .privacyPolicy:
            LegalDocumentSettingsView(
                title: "Privacy Policy",
                content: Self.privacyPolicyText
            )
        case .bandlabTesters:
            BandLabTestersSettingsView()
        case .backendApiTest:
            BeatFinderBackendTestView()
        }
    }

    private func clearCache() {
        guard !isClearingCache else { return }
        isClearingCache = true

        Task { @MainActor in
            URLCache.shared.removeAllCachedResponses()

            let tempDirectory = FileManager.default.temporaryDirectory
            if let contents = try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil) {
                for url in contents {
                    try? FileManager.default.removeItem(at: url)
                }
            }

            isClearingCache = false
            BeatHaptics.success()
            presentFeedback("App cache cleared")
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true

        Task { @MainActor in
            await appState.authStore.signOut()
            isSigningOut = false
        }
    }

    private func presentFeedback(_ message: String) {
        feedbackMessage = message

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard feedbackMessage == message else { return }
            withAnimation(MotionTokens.fastEase) {
                feedbackMessage = nil
            }
        }
    }

    private static let termsOfUseText = """
    BeatFinder is provided to help creators discover, save, and manage beats. By using the app, you agree to keep your account secure, respect creator licensing, and avoid uploading content you do not have permission to use.

    Membership plans renew automatically until canceled. Saved beats, lyric notes, and account preferences may sync across supported devices when your account is active.

    You are responsible for the lyrics, metadata, links, and media associated with your account. BeatFinder may update product features, creator tools, and subscription benefits over time.
    """

    private static let privacyPolicyText = """
    BeatFinder stores account details, saved beats, lyric notes, messaging data, and preferences needed to power your experience. Privacy controls inside Settings let you manage profile visibility, direct messages, activity sharing, and related preferences.

    Uploaded media, linked accounts, and support requests are processed only to deliver product functionality. Additional backend privacy controls can be added as the production account system expands.

    Local device preferences, cached artwork, and temporary previews can be cleared without removing your account or saved data.
    """
}

enum SettingsDestination: Hashable {
    case account
    case verification
    case changePassword
    case linkedAccounts
    case likedPosts
    case wallet
    case notifications
    case privacy
    case security
    case language
    case appearance
    case screenCapturing
    case helpCenter
    case reportProblem
    case termsOfUse
    case privacyPolicy
    case bandlabTesters
    case backendApiTest
}

private struct SettingsToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(BeatColors.accentBlueText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(BeatColors.accentBlue)
            )
            .shadow(color: BeatColors.accentBlueGlow, radius: 18, x: 0, y: 8)
    }
}

private struct SettingsToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    SettingsToastBanner(message: message)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(MotionTokens.fastEase, value: message)
    }
}

private extension View {
    func settingsToast(message: Binding<String?>) -> some View {
        modifier(SettingsToastModifier(message: message))
    }
}

private struct SettingsDetailScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScreenContainer(
            spacing: 18,
            topPadding: 16,
            bottomPadding: 24,
            maxWidthStyle: .standard,
            includeTabBarClearance: true
        ) {
            Color.black
        } content: {
            HStack {
                Button {
                    BeatHaptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))

                Spacer()

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Color.clear
                    .frame(width: 42, height: 42)
            }

            content
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SettingsInfoCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accentColor: Color = BeatColors.accentBlue

    var body: some View {
        SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BeatColors.textSecondary)
                }
            }
        }
    }
}

private struct SettingsFieldCard: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .never
    var disableAutocorrection = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeatColors.textSecondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        }
    }
}

private struct SettingsSecureFieldCard: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeatColors.textSecondary)

            SecureField(placeholder, text: $text)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        }
    }
}

private struct SettingsMultilineFieldCard: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var characterLimit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.textSecondary)

                Spacer()

                if let characterLimit {
                    Text("\(text.count)/\(characterLimit)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BeatColors.textTertiary)
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))

                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BeatColors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 140)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

private struct SettingsLineItem: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SettingsInlineToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(BeatColors.accentBlueStrong)
        }
    }
}

private struct SettingsToggleCard: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
            SettingsInlineToggleRow(title: title, subtitle: subtitle, isOn: $isOn)
        }
    }
}

private struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BeatColors.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BeatColors.textTertiary)
                }
            }
        }
        .buttonStyle(BeatPressableButtonStyle())
    }
}

private struct ModerationUser: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let handle: String
}

private struct HelpArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
}

private enum LinkedPlatform: String, CaseIterable, Identifiable {
    case apple
    case google
    case bandlab
    case soundCloud
    case youTube

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .bandlab: return "BandLab"
        case .soundCloud: return "SoundCloud"
        case .youTube: return "YouTube"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return "Use Sign in with Apple for faster access."
        case .google: return "Link your Google account for creator tools."
        case .bandlab: return "Connect your BandLab identity and collaboration graph."
        case .soundCloud: return "Bring in your SoundCloud creator presence."
        case .youTube: return "Connect your channel for previews and social proof."
        }
    }

    var badgeText: String {
        switch self {
        case .apple: return "A"
        case .google: return "G"
        case .bandlab: return "B"
        case .soundCloud: return "SC"
        case .youTube: return "YT"
        }
    }
}

private enum ModerationListKind {
    case blocked
    case muted

    var title: String {
        switch self {
        case .blocked: return "Blocked Users"
        case .muted: return "Muted Users"
        }
    }

    var storageKey: String {
        switch self {
        case .blocked: return "settings.privacy.blockedUsers"
        case .muted: return "settings.privacy.mutedUsers"
        }
    }

    var emptyTitle: String {
        switch self {
        case .blocked: return "No blocked users"
        case .muted: return "No muted users"
        }
    }

    var emptySubtitle: String {
        switch self {
        case .blocked: return "People you block will appear here so you can review or unblock them."
        case .muted: return "Muted users will appear here so you can restore their activity later."
        }
    }

    var actionTitle: String {
        switch self {
        case .blocked: return "Unblock"
        case .muted: return "Unmute"
        }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore

    @AppStorage("beatfinder.profile.username") private var storedUsername = ""
    @AppStorage("beatfinder.profile.displayName") private var storedDisplayName = ""
    @AppStorage("beatfinder.profile.bio") private var storedBio = ""
    @AppStorage("beatfinder.profile.avatarData") private var storedAvatarData = Data()

    @State private var emailAddress = "Loading…"
    @State private var draftUsername = ""
    @State private var draftDisplayName = ""
    @State private var draftBio = ""
    @State private var pendingAvatarImage: UIImage?
    @State private var removedAvatar = false
    @State private var pickedAvatarItem: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var isPhotoOptionsPresented = false
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var toastMessage: String?

    private var resolvedUsername: String {
        if !storedUsername.isEmpty { return storedUsername }
        if !appState.session.username.isEmpty { return appState.session.username }
        return "beatfinder"
    }

    private var resolvedDisplayName: String {
        if !storedDisplayName.isEmpty { return storedDisplayName }
        if !appState.session.displayName.isEmpty { return appState.session.displayName }
        return resolvedUsername
    }

    private var membershipTitle: String {
        appState.subscription.accessLevel == .goPlus ? "BeatFinder Plus" : "Free Plan"
    }

    private var accountStatus: String {
        appState.session.isVerified ? "Verified" : "Standard"
    }

    private var avatarPreviewImage: UIImage? {
        if let pendingAvatarImage {
            return pendingAvatarImage
        }

        guard !removedAvatar, !storedAvatarData.isEmpty else { return nil }
        return UIImage(data: storedAvatarData)
    }

    private var hasChanges: Bool {
        let trimmedUsername = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedDisplayName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedUsername != resolvedUsername.lowercased()
            || trimmedDisplayName != resolvedDisplayName
            || trimmedBio != storedBio
            || pendingAvatarImage != nil
            || removedAvatar
    }

    var body: some View {
        SettingsDetailScaffold(title: "Account") {
            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                HStack(spacing: 16) {
                    avatar

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile Basics")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Manage your profile photo, username, display name, and bio.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()
                }

                Button {
                    isPhotoOptionsPresented = true
                } label: {
                    HStack {
                        Text("Change profile photo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(BeatColors.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(BeatPressableButtonStyle())

                SettingsFieldCard(
                    title: "Username",
                    placeholder: "Username",
                    text: $draftUsername,
                    autocapitalization: .never
                )

                SettingsFieldCard(
                    title: "Display Name",
                    placeholder: "Display name",
                    text: $draftDisplayName,
                    autocapitalization: .words,
                    disableAutocorrection: false
                )

                SettingsMultilineFieldCard(
                    title: "Bio",
                    placeholder: "Add a short bio",
                    text: $draftBio,
                    characterLimit: 120
                )
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Account Info")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                SettingsLineItem(title: "Email", value: emailAddress)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsLineItem(title: "Membership", value: membershipTitle)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsLineItem(title: "Account Status", value: accountStatus)
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.danger)
            }

            PrimaryButton(title: isSaving ? "Saving…" : "Save Changes", kind: .light) {
                Task { await saveChanges() }
            }
            .disabled(isSaving || !hasChanges || draftUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickedAvatarItem, matching: .images)
        .confirmationDialog("Profile Photo", isPresented: $isPhotoOptionsPresented, titleVisibility: .visible) {
            Button("Choose from Photos") {
                isPhotoPickerPresented = true
            }

            if avatarPreviewImage != nil || !storedAvatarData.isEmpty || appState.session.avatarURL != nil {
                Button("Remove photo", role: .destructive) {
                    pendingAvatarImage = nil
                    removedAvatar = true
                }
            }

            Button("Cancel", role: .cancel) {}
        }
        .settingsToast(message: $toastMessage)
        .task {
            emailAddress = await authStore.currentEmail() ?? "Email unavailable"
            draftUsername = resolvedUsername
            draftDisplayName = resolvedDisplayName
            draftBio = storedBio
        }
        .onChange(of: draftBio) { _, newValue in
            if newValue.count > 120 {
                draftBio = String(newValue.prefix(120))
            }
        }
        .onChange(of: pickedAvatarItem) { _, newItem in
            guard let newItem else { return }

            Task { @MainActor in
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    pendingAvatarImage = image
                    removedAvatar = false
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private var avatar: some View {
        Group {
            if let image = avatarPreviewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if !removedAvatar, let avatarURL = appState.session.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.08))
                }
            } else {
                Circle()
                    .fill(BeatColors.surfaceSecondary)
                    .overlay(
                        Text(resolvedDisplayName.prefix(1).uppercased())
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func saveChanges() async {
        let cleanedUsername = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedDisplayName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedUsername.isEmpty else {
            errorText = "Username cannot be empty."
            return
        }

        isSaving = true
        errorText = nil

        do {
            if cleanedUsername != resolvedUsername.lowercased() {
                try await authStore.updateUsername(cleanedUsername)
            }

            if let pendingAvatarImage {
                try await authStore.uploadAvatar(image: pendingAvatarImage)
                if let jpeg = pendingAvatarImage.jpegData(compressionQuality: 0.9) {
                    storedAvatarData = jpeg
                }
            } else if removedAvatar {
                storedAvatarData = Data()
                appState.session.avatarURL = nil
            }

            storedUsername = cleanedUsername
            storedDisplayName = cleanedDisplayName
            storedBio = cleanedBio
            appState.session.username = cleanedUsername
            appState.session.displayName = cleanedDisplayName

            removedAvatar = false
            isSaving = false
            BeatHaptics.success()
            presentToast("Profile updated")
        } catch {
            isSaving = false
            errorText = error.localizedDescription
        }
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toastMessage == message else { return }
            toastMessage = nil
        }
    }
}

struct VerificationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("beatfinder.profile.username") private var storedUsername = ""
    @AppStorage("beatfinder.profile.avatarData") private var storedAvatarData = Data()
    @AppStorage("settings.verification.applied") private var isApplied = false
    @AppStorage("settings.verification.hasPostedBeat") private var hasPostedBeat = true
    @State private var activeSheet: PlaceholderDestination?

    private var emailConfirmed: Bool {
        appState.session.isAuthenticated
    }

    private var profilePhotoAdded: Bool {
        !storedAvatarData.isEmpty || appState.session.avatarURL != nil
    }

    private var usernameSet: Bool {
        let username = storedUsername.isEmpty ? appState.session.username : storedUsername
        return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SettingsDetailScaffold(title: "Verification") {
            SettingsInfoCard(
                title: "Get verified",
                subtitle: "Build trust and stand out on your profile.",
                systemImage: "checkmark.seal.fill"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Eligibility")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                verificationBullet("Email confirmed", isComplete: emailConfirmed)
                verificationBullet("Profile photo added", isComplete: profilePhotoAdded)
                verificationBullet("Username set", isComplete: usernameSet)
                verificationBullet("At least 1 posted beat", isComplete: hasPostedBeat)
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isApplied ? "Application Received" : "Current Status")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Text(isApplied ? "Your creator verification request is in review." : "You can start the verification flow once your profile feels ready.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isApplied ? "clock.badge.checkmark" : "checkmark.seal")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                }
            }

            PrimaryButton(title: isApplied ? "Continue" : "Start verification", kind: .light) {
                isApplied = true
                activeSheet = PlaceholderDestination(
                    id: "verification.start",
                    title: "Verification started",
                    message: "Verification submission will be connected to the backend soon.",
                    detail: "Keep your profile complete and ownership-ready so the request can be finalized quickly.",
                    systemImage: "checkmark.seal.fill",
                    buttonTitle: "Continue"
                )
            }

            PrimaryButton(title: "Learn requirements", kind: .dark) {
                activeSheet = PlaceholderDestination(
                    id: "verification.requirements",
                    title: "Verification Requirements",
                    message: "BeatFinder verification reviews identity confirmation, active creator status, and content ownership before approval.",
                    detail: "Requirements include a complete profile, public creator presence, and ownership-safe uploads.",
                    systemImage: "list.bullet.rectangle.portrait",
                    buttonTitle: "Got it"
                )
            }
        }
        .sheet(item: $activeSheet) { destination in
            PlaceholderDetailView(destination: destination)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func verificationBullet(_ text: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isComplete ? BeatColors.accentBlue : BeatColors.textTertiary)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }
}

struct ChangePasswordSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @AppStorage("settings.password.lastChanged") private var lastChanged = ""

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var didSave = false
    @State private var isSubmitting = false
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var toastMessage: String?

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var hasMinLength: Bool {
        newPassword.count >= 8
    }

    private var hasNumber: Bool {
        newPassword.contains(where: \.isNumber)
    }

    private var canSave: Bool {
        !currentPassword.isEmpty && hasMinLength && hasNumber && passwordsMatch
    }

    var body: some View {
        SettingsDetailScaffold(title: "Change Password") {
            SettingsInfoCard(
                title: "Update Password",
                subtitle: "Use at least 8 characters and confirm the new password before saving.",
                systemImage: "key.horizontal.fill"
            )

            SettingsSecureFieldCard(title: "Current Password", placeholder: "Current password", text: $currentPassword)
            SettingsSecureFieldCard(title: "New Password", placeholder: "New password", text: $newPassword)
            SettingsSecureFieldCard(title: "Confirm New Password", placeholder: "Confirm new password", text: $confirmPassword)

            SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                Text("Password rules")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                passwordRule("Minimum 8 characters", met: hasMinLength)
                passwordRule("At least 1 number", met: hasNumber)
            }

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("New password and confirmation must match.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.danger)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.danger)
            }

            if let infoMessage, !infoMessage.isEmpty {
                Text(infoMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            if didSave {
                Text("Password updated")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.accentBlue)
            }

            PrimaryButton(title: isSubmitting ? "Updating…" : "Update password", kind: .light) {
                Task { await updatePassword() }
            }
            .disabled(!canSave || isSubmitting)
        }
        .settingsToast(message: $toastMessage)
    }

    private func passwordRule(_ text: String, met: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? BeatColors.accentBlue : BeatColors.textTertiary)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }

    private func updatePassword() async {
        guard canSave else { return }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        didSave = false

        do {
            try await authStore.updatePassword(newPassword)
            lastChanged = Date().formatted(date: .abbreviated, time: .omitted)
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            didSave = true
            BeatHaptics.success()
            presentToast("Password updated")
        } catch {
            infoMessage = "Password update flow will connect to authentication backend if the current session does not support direct updates yet."
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toastMessage == message else { return }
            toastMessage = nil
        }
    }
}

struct LinkedAccountsSettingsView: View {
    @AppStorage("settings.linked.apple") private var isAppleLinked = true
    @AppStorage("settings.linked.google") private var isGoogleLinked = false
    @AppStorage("settings.linked.bandlab") private var isBandLabLinked = false
    @AppStorage("settings.linked.soundcloud") private var isSoundCloudLinked = false
    @AppStorage("settings.linked.youtube") private var isYouTubeLinked = false
    @State private var pendingDisconnect: LinkedPlatform?
    @State private var toastMessage: String?

    var body: some View {
        SettingsDetailScaffold(title: "Linked Accounts") {
            SettingsInfoCard(
                title: "Connection Summary",
                subtitle: "Linked platforms help BeatFinder verify identity, import creator context, and unlock social tools.",
                systemImage: "link.circle.fill"
            )

            linkedRow(platform: .apple, isLinked: $isAppleLinked)
            linkedRow(platform: .google, isLinked: $isGoogleLinked)
            linkedRow(platform: .bandlab, isLinked: $isBandLabLinked)
            linkedRow(platform: .soundCloud, isLinked: $isSoundCloudLinked)
            linkedRow(platform: .youTube, isLinked: $isYouTubeLinked)
        }
        .settingsToast(message: $toastMessage)
        .confirmationDialog(
            pendingDisconnect.map { "Disconnect \($0.title)?" } ?? "Disconnect Account",
            isPresented: Binding(
                get: { pendingDisconnect != nil },
                set: { if !$0 { pendingDisconnect = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                guard let pendingDisconnect else { return }
                linkedBinding(for: pendingDisconnect).wrappedValue = false
                self.pendingDisconnect = nil
                presentToast("\(pendingDisconnect.title) disconnected")
            }
        } message: {
            Text("This linked account will be removed from your BeatFinder profile.")
        }
    }

    private func linkedRow(platform: LinkedPlatform, isLinked: Binding<Bool>) -> some View {
        SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
            HStack(spacing: 14) {
                Text(platform.badgeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isLinked.wrappedValue ? BeatColors.accentBlueText : .white)
                    .frame(width: 34, height: 34)
                    .background(isLinked.wrappedValue ? BeatColors.accentBlue : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(platform.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(isLinked.wrappedValue ? "Connected" : "Not connected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isLinked.wrappedValue ? BeatColors.accentBlue : BeatColors.textSecondary)

                    Text(platform.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BeatColors.textTertiary)
                }

                Spacer()

                Button(isLinked.wrappedValue ? "Disconnect" : "Connect") {
                    if isLinked.wrappedValue {
                        pendingDisconnect = platform
                    } else {
                        isLinked.wrappedValue = true
                        presentToast("\(platform.title) linking will be enabled soon. Demo connection is active for now.")
                    }
                }
                .buttonStyle(BeatPressableButtonStyle())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isLinked.wrappedValue ? .white : BeatColors.accentBlueText)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(isLinked.wrappedValue ? Color.white.opacity(0.08) : BeatColors.accentBlue)
                .clipShape(Capsule())
            }
        }
    }

    private func linkedBinding(for platform: LinkedPlatform) -> Binding<Bool> {
        switch platform {
        case .apple: return $isAppleLinked
        case .google: return $isGoogleLinked
        case .bandlab: return $isBandLabLinked
        case .soundCloud: return $isSoundCloudLinked
        case .youTube: return $isYouTubeLinked
        }
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toastMessage == message else { return }
            toastMessage = nil
        }
    }
}

struct LikedPostsSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var likes: LikeService
    @State private var selectedBeat: BeatResultModel?

    private var likedResults: [BeatResultModel] {
        likes.likedBeatIds.sorted { $0.uuidString < $1.uuidString }.enumerated().map { index, id in
            BeatResultModel(
                id: id.uuidString,
                title: "Liked Beat \(index + 1)",
                artist: "BeatFinder Creator",
                bpm: 120 + index,
                genre: index.isMultiple(of: 2) ? "Trap" : "R&B",
                releaseDate: Date().addingTimeInterval(Double(-86_400 * index)),
                artworkName: "nest_music",
                youtubeVideoID: "dQw4w9WgXcQ",
                youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            )
        }
    }

    var body: some View {
        SettingsDetailScaffold(title: "Liked Posts") {
            if likedResults.isEmpty {
                SettingsInfoCard(
                    title: "No liked posts yet",
                    subtitle: "Beats you like will appear here.",
                    systemImage: "heart"
                )

                PrimaryButton(title: "Go to Explore", kind: .light) {
                    appState.profilePath = []
                    appState.selectedTab = .home
                }
            } else {
                ForEach(likedResults, id: \.id) { beat in
                    Button {
                        selectedBeat = beat
                    } label: {
                        SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(BeatColors.surfaceSecondary)
                                    .frame(width: 68, height: 68)
                                    .overlay(
                                        Image(beat.artworkName ?? "nest_music")
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(beat.title)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(beat.artist)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(BeatColors.textSecondary)

                                    Text("\(beat.genre) • \(beat.bpm) BPM")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(BeatColors.textTertiary)
                                }

                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }
            }
        }
        .fullScreenCover(item: $selectedBeat) { beat in
            NavigationStack {
                UploadResultView(model: beat, sourceContext: .explore)
            }
            .preferredColorScheme(.dark)
        }
        .task {
            guard let userID = appState.session.userID else { return }
            await likes.loadLikes(for: userID)
        }
    }
}

struct NotificationsSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore

    @AppStorage("settings.notifications.push") private var pushNotifications = true
    @AppStorage("settings.notifications.email") private var emailNotifications = false
    @AppStorage("settings.notifications.newFollowers") private var newFollowers = true
    @AppStorage("settings.notifications.likes") private var likesOnMyBeats = true
    @AppStorage("settings.notifications.commentsMessages") private var commentsMessages = true
    @AppStorage("settings.notifications.matches") private var newBeatMatches = true
    @AppStorage("settings.notifications.membership") private var membershipUpdates = true
    @AppStorage("settings.notifications.payments") private var paymentActivity = true
    @AppStorage("settings.notifications.announcements") private var featureAnnouncements = true

    @State private var pushStatusText = "Checking notification permissions…"
    @State private var accountEmail = ""

    var body: some View {
        SettingsDetailScaffold(title: "Notifications") {
            SettingsInfoCard(
                title: "Notification Preferences",
                subtitle: "Choose the BeatFinder activity you want to hear about first.",
                systemImage: "bell.badge.fill"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Beat Activity")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                SettingsInlineToggleRow(title: "New followers", subtitle: "Alerts when people follow your profile.", isOn: $newFollowers)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(title: "Likes on my beats", subtitle: "Know when listeners like your content.", isOn: $likesOnMyBeats)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(title: "Comments / messages", subtitle: "Updates for chats and feedback.", isOn: $commentsMessages)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(title: "New beat matches", subtitle: "Matching results and fresh saved finds.", isOn: $newBeatMatches)
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Product / Membership")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                SettingsInlineToggleRow(title: "Subscription updates", subtitle: "Renewals, plan changes, and restore events.", isOn: $membershipUpdates)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(title: "Payment activity", subtitle: "Charges, payouts, and billing changes.", isOn: $paymentActivity)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(title: "Feature announcements", subtitle: "Major releases and important product news.", isOn: $featureAnnouncements)
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Delivery")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                SettingsInlineToggleRow(title: "Push notifications", subtitle: pushStatusText, isOn: $pushNotifications)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(
                    title: "Email notifications",
                    subtitle: accountEmail.isEmpty ? "Email delivery needs a confirmed email on your account." : "Deliver updates to \(accountEmail).",
                    isOn: $emailNotifications
                )
            }
        }
        .task {
            accountEmail = await authStore.currentEmail() ?? ""
            await refreshPermissionState()
        }
        .onChange(of: pushNotifications) { _, newValue in
            guard newValue else { return }
            Task { await requestPushPermissionIfNeeded() }
        }
    }

    private func refreshPermissionState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                pushStatusText = "Push enabled on this device."
            case .denied:
                pushStatusText = "Push is disabled in system settings."
            case .notDetermined:
                pushStatusText = "Enable to receive device alerts."
            @unknown default:
                pushStatusText = "Notification state unavailable."
            }
        }
    }

    private func requestPushPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                await MainActor.run {
                    pushNotifications = granted
                }
            } catch {
                await MainActor.run {
                    pushNotifications = false
                }
            }
        }

        await refreshPermissionState()
    }
}

struct PrivacySettingsView: View {
    @AppStorage("settings.privacy.privateProfile") private var privateProfile = false
    @AppStorage("settings.privacy.showFollowers") private var showFollowers = true
    @AppStorage("settings.privacy.showFollowing") private var showFollowing = true
    @AppStorage("settings.privacy.showPlays") private var showPlays = true
    @AppStorage("settings.privacy.allowDirectMessages") private var allowDirectMessages = true
    @AppStorage("settings.privacy.showActivityStatus") private var showActivityStatus = true

    var body: some View {
        SettingsDetailScaffold(title: "Privacy") {
            SettingsInfoCard(
                title: "Privacy Controls",
                subtitle: "Manage profile visibility, direct messages, and activity sharing.",
                systemImage: "lock.fill"
            )

            SettingsToggleCard(title: "Private profile", subtitle: "Require approval before others can follow you.", isOn: $privateProfile)
            SettingsToggleCard(title: "Show followers count", subtitle: "Display the number of followers on your profile.", isOn: $showFollowers)
            SettingsToggleCard(title: "Show following count", subtitle: "Display who you follow and how many.", isOn: $showFollowing)
            SettingsToggleCard(title: "Show plays count", subtitle: "Show play totals across your profile.", isOn: $showPlays)
            SettingsToggleCard(title: "Allow direct messages", subtitle: "Let other users open a conversation with you.", isOn: $allowDirectMessages)
            SettingsToggleCard(title: "Show activity status", subtitle: "Indicate when you were active recently.", isOn: $showActivityStatus)

            SettingsNavigationRow(
                title: "Blocked users",
                subtitle: "Review people you’ve blocked.",
                systemImage: "hand.raised.fill"
            ) {
                ModerationUsersSettingsView(kind: .blocked)
            }

            SettingsNavigationRow(
                title: "Muted users",
                subtitle: "Review muted creators and listeners.",
                systemImage: "speaker.slash.fill"
            ) {
                ModerationUsersSettingsView(kind: .muted)
            }
        }
    }
}

struct SecuritySettingsView: View {
    @AppStorage("settings.security.biometricUnlock") private var biometricUnlock = false
    @AppStorage("settings.security.requirePasscode") private var requirePasscode = false
    @AppStorage("settings.security.loginAlerts") private var loginAlerts = true
    @AppStorage("settings.password.lastChanged") private var passwordLastChanged = ""

    @State private var isSignOutOtherSessionsPresented = false
    @State private var signedOutOtherSessions = false
    @State private var supportsBiometrics = false

    var body: some View {
        SettingsDetailScaffold(title: "Security") {
            SettingsInfoCard(
                title: "Account protection",
                subtitle: "Keep your BeatFinder account protected with device and session controls.",
                systemImage: "shield.lefthalf.filled"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                if supportsBiometrics {
                    SettingsInlineToggleRow(title: "Face ID / biometric unlock", subtitle: "Unlock BeatFinder with the device biometric you already use.", isOn: $biometricUnlock)
                    Divider().overlay(Color.white.opacity(0.06))
                } else {
                    SettingsLineItem(title: "Biometric unlock", value: "Not available on this device")
                    Divider().overlay(Color.white.opacity(0.06))
                }

                SettingsInlineToggleRow(title: "Require passcode on app open", subtitle: "Ask for a local passcode when BeatFinder opens.", isOn: $requirePasscode)
                Divider().overlay(Color.white.opacity(0.06))
                SettingsInlineToggleRow(title: "Login alerts", subtitle: "Notify you when a new session signs in.", isOn: $loginAlerts)
            }

            SettingsNavigationRow(
                title: "Two-factor authentication",
                subtitle: "View current status and setup details.",
                systemImage: "number.circle.fill"
            ) {
                TwoFactorSettingsView()
            }

            SettingsNavigationRow(
                title: "Trusted devices",
                subtitle: "Review devices that have signed in recently.",
                systemImage: "desktopcomputer"
            ) {
                TrustedDevicesSettingsView()
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                SettingsLineItem(title: "Login Activity", value: "2 recent logins")
                Divider().overlay(Color.white.opacity(0.06))
                SettingsLineItem(title: "Password Last Changed", value: passwordLastChanged.isEmpty ? "Not available" : passwordLastChanged)
            }

            Button {
                isSignOutOtherSessionsPresented = true
            } label: {
                SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sign out other sessions")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            Text(signedOutOtherSessions ? "All other sessions were closed." : "End access on devices other than this one.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BeatColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BeatColors.accentBlue)
                    }
                }
            }
            .buttonStyle(BeatPressableButtonStyle())
        }
        .task {
            let context = LAContext()
            var error: NSError?
            supportsBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        }
        .confirmationDialog("Sign out other sessions?", isPresented: $isSignOutOtherSessionsPresented, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out Sessions", role: .destructive) {
                signedOutOtherSessions = true
            }
        } message: {
            Text("Your other active sessions will be closed.")
        }
    }
}

struct TwoFactorSettingsView: View {
    @AppStorage("settings.security.twoFactor") private var twoFactorEnabled = false
    @State private var activeSheet: PlaceholderDestination?

    var body: some View {
        SettingsDetailScaffold(title: "Two-Factor Authentication") {
            SettingsInfoCard(
                title: "Two-factor authentication",
                subtitle: "Add a second step when signing in to protect your account.",
                systemImage: "number.circle.fill"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                SettingsLineItem(title: "Status", value: twoFactorEnabled ? "Enabled" : "Not enabled")
                Divider().overlay(Color.white.opacity(0.06))
                Text("Two-factor setup will be connected soon.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            PrimaryButton(title: twoFactorEnabled ? "Continue" : "Start setup", kind: .light) {
                twoFactorEnabled = true
                activeSheet = PlaceholderDestination(
                    id: "twofactor.setup",
                    title: "Two-factor setup",
                    message: "Two-factor setup will be connected soon.",
                    detail: "For now, the status can be stored locally for product testing.",
                    systemImage: "number.circle.fill",
                    buttonTitle: "Continue"
                )
            }
        }
        .sheet(item: $activeSheet) { destination in
            PlaceholderDetailView(destination: destination)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct TrustedDevicesSettingsView: View {
    private let devices: [(String, String)] = [
        ("iPad", "Current device · Recently active"),
        ("iPhone", "Seen yesterday · Trusted")
    ]

    var body: some View {
        SettingsDetailScaffold(title: "Trusted Devices") {
            ForEach(devices, id: \.0) { name, detail in
                SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                    HStack(spacing: 14) {
                        Image(systemName: name == "iPad" ? "ipad.landscape" : "iphone")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BeatColors.accentBlue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            Text(detail)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BeatColors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

struct LanguageSettingsView: View {
    @AppStorage("settings.language.selected") private var selectedLanguage = "English"
    @State private var toastMessage: String?

    private let languages = ["English", "Spanish", "French"]

    var body: some View {
        SettingsDetailScaffold(title: "Language") {
            SettingsInfoCard(
                title: "Language",
                subtitle: "Choose the primary language BeatFinder should prefer on this device.",
                systemImage: "globe"
            )

            ForEach(languages, id: \.self) { language in
                Button {
                    selectedLanguage = language
                    presentToast("Language updated")
                } label: {
                    SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                        HStack {
                            Text(language)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)

                            Spacer()

                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(BeatColors.accentBlue)
                            }
                        }
                    }
                }
                .buttonStyle(BeatPressableButtonStyle())
            }

            Text("More app text will localize in future updates.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
        .settingsToast(message: $toastMessage)
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toastMessage == message else { return }
            toastMessage = nil
        }
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @AppStorage("settings.appearance.glow") private var glowIntensity = "Standard"

    private let glowOptions = ["Low", "Standard", "High"]

    var body: some View {
        SettingsDetailScaffold(title: "Appearance") {
            SettingsInfoCard(
                title: "Appearance",
                subtitle: "Choose the visual mode BeatFinder should prefer for your device.",
                systemImage: "moon.stars.fill"
            )

            ForEach(SettingsStore.AppearanceMode.allCases) { mode in
                Button {
                    settings.appearanceModeOption = mode
                } label: {
                    SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                        HStack {
                            Text(mode.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)

                            Spacer()

                            if settings.appearanceModeOption == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(BeatColors.accentBlue)
                            }
                        }
                    }
                }
                .buttonStyle(BeatPressableButtonStyle())
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Accent glow intensity")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Picker("Glow", selection: $glowIntensity) {
                    ForEach(glowOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Text("BeatFinder currently ships with dark mode as the primary visual system, even when Light or System is selected.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }
}

struct ScreenCapturingSettingsView: View {
    @AppStorage("settings.capture.allowScreenshots") private var allowScreenshots = true
    @AppStorage("settings.capture.blurSwitcher") private var blurAppSwitcher = true
    @AppStorage("settings.capture.hideWalletBalances") private var hideWalletBalances = true

    var body: some View {
        SettingsDetailScaffold(title: "Screen Capturing") {
            SettingsInfoCard(
                title: "Recording Privacy",
                subtitle: "Choose how BeatFinder should behave when screenshots, recordings, and previews are involved.",
                systemImage: "record.circle.fill"
            )

            SettingsToggleCard(title: "Allow screenshots in app", subtitle: "Permit standard device screenshots while using BeatFinder.", isOn: $allowScreenshots)
            SettingsToggleCard(title: "Blur private account info in app switcher", subtitle: "Reduce sensitive content in recent app previews.", isOn: $blurAppSwitcher)
            SettingsToggleCard(title: "Hide sensitive wallet balances in previews", subtitle: "Prevent wallet balances from showing in preview surfaces.", isOn: $hideWalletBalances)

            Text("Some screen capture protections depend on OS behavior.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }
}

struct HelpCenterSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var searchText = ""

    private let articles: [HelpArticle] = [
        HelpArticle(id: "getting-started", title: "Getting started", body: "Create your profile, explore beats, and save the ones you want to revisit later. BeatFinder is built to keep your discovery flow fast and consistent across tabs."),
        HelpArticle(id: "memberships", title: "Memberships", body: "Membership plans unlock saved beats capacity, creator tools, and faster action paths. Restore purchases from the subscription modal when switching devices."),
        HelpArticle(id: "uploads", title: "Uploading beats", body: "Upload supports Files, video library imports, and pasted links. Select a source, review your media, and continue when the backend matching flow is ready."),
        HelpArticle(id: "saved-beats", title: "Saved beats", body: "Saved beats are available from the Safe tab and can be reopened into the same beat detail page you see from Explore."),
        HelpArticle(id: "account-security", title: "Account & security", body: "Use Settings to update your password, manage linked accounts, review security status, and control privacy preferences."),
        HelpArticle(id: "contact-support", title: "Contact support", body: "Support is available for account issues, subscriptions, matching questions, uploads, and creator profile help.")
    ]

    private var filteredArticles: [HelpArticle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        SettingsDetailScaffold(title: "Help Center") {
            SettingsFieldCard(
                title: "Search",
                placeholder: "Search help topics",
                text: $searchText,
                autocapitalization: .sentences,
                disableAutocorrection: false
            )

            ForEach(filteredArticles) { article in
                NavigationLink {
                    HelpArticleSettingsView(article: article)
                } label: {
                    SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BeatColors.accentBlue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(article.body)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(BeatColors.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(BeatColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(BeatPressableButtonStyle())
            }

            PrimaryButton(title: "Contact support", kind: .light) {
                if let url = URL(string: "mailto:support@beatfinder.app?subject=BeatFinder%20Support") {
                    openURL(url)
                }
            }
        }
    }
}

private struct HelpArticleSettingsView: View {
    let article: HelpArticle

    var body: some View {
        SettingsDetailScaffold(title: article.title) {
            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text(article.body)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ReportProblemSettingsView: View {
    @State private var selectedCategory = "Bug"
    @State private var description = ""
    @State private var includeScreenshot = false
    @State private var toastMessage: String?

    private let categories = ["Bug", "Payment", "Account", "Upload", "Messaging", "Other"]

    var body: some View {
        SettingsDetailScaffold(title: "Report a Problem") {
            SettingsInfoCard(
                title: "Tell us what happened",
                subtitle: "Add a category, describe the issue, and submit it for review.",
                systemImage: "exclamationmark.bubble.fill"
            )

            SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Issue Type")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)

                        Text(selectedCategory)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Choose")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BeatColors.accentBlueText)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(BeatColors.accentBlue)
                        .clipShape(Capsule())
                    }
                }
            }

            SettingsMultilineFieldCard(
                title: "Description",
                placeholder: "Describe the problem in as much detail as you can.",
                text: $description
            )

            SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                SettingsInlineToggleRow(
                    title: "Attach screenshot",
                    subtitle: "Attachment routing is queued for the next backend pass.",
                    isOn: $includeScreenshot
                )
            }

            PrimaryButton(title: "Submit", kind: .light) {
                BeatHaptics.success()
                presentToast("Your report has been saved and support routing will be connected soon.")
                description = ""
                includeScreenshot = false
            }
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .settingsToast(message: $toastMessage)
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard toastMessage == message else { return }
            toastMessage = nil
        }
    }
}

struct LegalDocumentSettingsView: View {
    let title: String
    let content: String

    var body: some View {
        SettingsDetailScaffold(title: title) {
            SettingsInfoCard(
                title: title,
                subtitle: "Read the latest current in-app version of this policy.",
                systemImage: "doc.text.fill"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text(content)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.84))
                    .textSelection(.enabled)
            }
        }
    }
}

struct BandLabTestersSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var activeSheet: PlaceholderDestination?

    var body: some View {
        SettingsDetailScaffold(title: "Join BeatFinder AI Testers") {
            SettingsInfoCard(
                title: "Tester Access",
                subtitle: "Apply for early AI product experiments, beta workflows, and creator feedback programs.",
                systemImage: "testtube.2"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("BeatFinder AI Testers preview upcoming AI-assisted creator features, workflow improvements, and product experiments before public release.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)

                Divider().overlay(Color.white.opacity(0.06))
                Text("Benefits include:")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                testerBenefit("Early access to creator workflow experiments")
                testerBenefit("Feedback loops on new publishing and matching tools")
                testerBenefit("A direct path to influence what ships next")
            }

            PrimaryButton(title: "Request access", kind: .light) {
                activeSheet = PlaceholderDestination(
                    id: "bandlab.request",
                    title: "Request saved",
                    message: "BeatFinder AI tester requests will be connected soon.",
                    detail: "We’ll keep the flow polished so it can hook into the real access pipeline later.",
                    systemImage: "testtube.2",
                    buttonTitle: "Done"
                )
            }

            PrimaryButton(title: "Learn more", kind: .dark) {
                if let url = URL(string: "https://www.bandlab.com") {
                    openURL(url)
                }
            }
        }
        .sheet(item: $activeSheet) { destination in
            PlaceholderDetailView(destination: destination)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func testerBenefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(BeatColors.accentBlue)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }
}

private struct ModerationUsersSettingsView: View {
    let kind: ModerationListKind

    @State private var searchText = ""
    @State private var users: [ModerationUser] = []

    private var filteredUsers: [ModerationUser] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.handle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        SettingsDetailScaffold(title: kind.title) {
            if users.isEmpty {
                SettingsInfoCard(
                    title: kind.emptyTitle,
                    subtitle: kind.emptySubtitle,
                    systemImage: kind == .blocked ? "hand.raised.fill" : "speaker.slash.fill"
                )
            } else {
                SettingsFieldCard(
                    title: "Search",
                    placeholder: "Search users",
                    text: $searchText,
                    autocapitalization: .never,
                    disableAutocorrection: true
                )

                ForEach(filteredUsers) { user in
                    SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(BeatColors.surfaceSecondary)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(user.name.prefix(1).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("@\(user.handle)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(BeatColors.textSecondary)
                            }

                            Spacer()

                            Button(kind.actionTitle) {
                                remove(user)
                            }
                            .buttonStyle(BeatPressableButtonStyle())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(BeatColors.accentBlueText)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(BeatColors.accentBlue)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .task {
            load()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: kind.storageKey),
              let decoded = try? JSONDecoder().decode([ModerationUser].self, from: data)
        else {
            users = []
            return
        }

        users = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(users) else { return }
        UserDefaults.standard.set(data, forKey: kind.storageKey)
    }

    private func remove(_ user: ModerationUser) {
        users.removeAll { $0.id == user.id }
        persist()
    }
}
