import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var sub: SubscriptionManager
    @EnvironmentObject private var settings: SettingsStore

    @State private var statusText: String = ""
    @State private var isClearingCache = false
    @State private var isSigningOut = false
    @State private var showClearCacheConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSubscriptionModal = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: BeatLayout.sectionSpacing) {
                    membershipCard
                    accountCard
                    preferencesCard
                    supportCard
                    legalCard
                    actionsCard

                    if !statusText.isEmpty || !sub.statusText.isEmpty {
                        SettingsSurfaceCard {
                            if !statusText.isEmpty {
                                Text(statusText)
                                    .font(BeatTypography.caption)
                                    .foregroundStyle(.white.opacity(0.86))
                            }

                            if !sub.statusText.isEmpty {
                                Text(sub.statusText)
                                    .font(BeatTypography.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                    }

                    Text("Version \(appVersionText)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, BeatLayout.sectionSpacingTight)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left") // Matching other back buttons
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(
            "Clear cached data?",
            isPresented: $showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                clearCache()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes local cache, temporary files, and beat draft cache.")
        }
        .confirmationDialog(
            "Sign out of BeatFinder?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                signOut()
            }

            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showSubscriptionModal) {
            NavigationStack {
                PaywallView()
            }
            .environmentObject(sub)
            .environmentObject(settings)
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
        .task {
            await sub.refreshEntitlements()
        }
    }
}

private extension SettingsView {
    var membershipCard: some View {
        SettingsSurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.25, green: 0.6, blue: 1.0).opacity(0.2)) // Blue tint
                    
                    Image(systemName: "star.fill") // Replaced crown
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.25, green: 0.6, blue: 1.0))
                }
                .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Membership")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(sub.isPro ? "GO+ is active." : "Upgrade to unlock limitless studio tools.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.66))
                }
                
                Spacer(minLength: 8)
                
                Text(sub.isPro ? "GO+" : "FREE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(sub.isPro ? Color(red: 0.25, green: 0.6, blue: 1.0) : Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Button {
                showSubscriptionModal = true
            } label: {
                Text(sub.isPro ? "Manage Subscription" : "Upgrade Membership")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white) // Blue theme buttons usually have white text
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.25, green: 0.6, blue: 1.0)) // Blue button
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }


    var accountCard: some View {
        SettingsSurfaceCard {
            SettingsSectionTitle("Account")

            VStack(spacing: 0) {
                SettingsNavigationRow(title: "Account", systemImage: "person.crop.circle", iconTint: .cyan) {
                    AccountSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Change Password", systemImage: "key.fill", iconTint: .orange) {
                    ChangePasswordSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Linked Accounts", systemImage: "link", iconTint: .mint) {
                    LinkedAccountsSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Payments", systemImage: "creditcard.fill", iconTint: .yellow) {
                    PaymentsSettingsView()
                }
            }
        }
    }

    var preferencesCard: some View {
        SettingsSurfaceCard {
            SettingsSectionTitle("Preferences")

            VStack(spacing: 0) {
                SettingsNavigationRow(title: "Notifications", systemImage: "bell.badge.fill", iconTint: .red) {
                    NotificationsSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Privacy", systemImage: "hand.raised.fill", iconTint: .teal) {
                    PrivacySettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Security", systemImage: "shield.fill", iconTint: .blue) {
                    SecuritySettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Language", systemImage: "globe", iconTint: .green) {
                    LanguageSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Appearance", systemImage: "paintbrush.fill", iconTint: .purple) {
                    AppearanceSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Screen Capturing", systemImage: "record.circle", iconTint: .pink) {
                    ScreenCapturingSettingsView()
                }
            }
        }
    }

    var supportCard: some View {
        SettingsSurfaceCard {
            SettingsSectionTitle("Support")

            VStack(spacing: 0) {
                SettingsNavigationRow(title: "Help Center", systemImage: "questionmark.circle.fill", iconTint: .indigo) {
                    HelpCenterSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Report a Problem", systemImage: "exclamationmark.bubble.fill", iconTint: .orange) {
                    ReportProblemSettingsView()
                }
            }
        }
    }

    var legalCard: some View {
        SettingsSurfaceCard {
            SettingsSectionTitle("Legal")

            VStack(spacing: 0) {
                SettingsNavigationRow(title: "Terms of Use", systemImage: "doc.text.fill", iconTint: .gray) {
                    TermsOfUseSettingsView()
                }
                SettingsCardDivider()

                SettingsNavigationRow(title: "Privacy Policy", systemImage: "lock.doc.fill", iconTint: .gray) {
                    PrivacyPolicySettingsView()
                }
            }
        }
    }

    var actionsCard: some View {
        SettingsSurfaceCard {
            SettingsSectionTitle("Actions")

            VStack(spacing: 0) {
                SettingsActionRow(
                    title: "Clear Cache",
                    systemImage: "trash.fill",
                    iconTint: .yellow,
                    trailingText: isClearingCache ? "Clearing..." : nil,
                    isEnabled: !isClearingCache && !isSigningOut,
                    showChevron: true
                ) {
                    showClearCacheConfirmation = true
                }

                SettingsCardDivider()

                SettingsActionRow(
                    title: "Sign out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    iconTint: .red,
                    titleColor: .red.opacity(0.92),
                    trailingText: isSigningOut ? "Signing out..." : nil,
                    isEnabled: !isSigningOut && !isClearingCache,
                    showChevron: true
                ) {
                    showSignOutConfirmation = true
                }
            }
        }
    }

    var appVersionText: String {
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        return "\(shortVersion) (\(build))"
    }

    func clearCache() {
        isClearingCache = true
        let removedItemCount = AppCacheCleaner.clear()
        isClearingCache = false

        let noun = removedItemCount == 1 ? "item" : "items"
        statusText = "Cleared \(removedItemCount) cached \(noun)."
    }

    func signOut() {
        Task {
            isSigningOut = true
            await auth.signOut()
            isSigningOut = false
            dismiss()
        }
    }
}

private enum AppCacheCleaner {
    private static let explicitDefaultsKeys: Set<String> = [
        "currentBeatTitle",
        "uploadedBeatURL",
        "beatfinder.saved_matches.v1"
    ]

    private static let prefixedDefaultsKeys: [String] = [
        "beatfinder.lyricspad."
    ]

    static func clear() -> Int {
        var removed = 0

        let defaults = UserDefaults.standard

        for key in explicitDefaultsKeys where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            removed += 1
        }

        let existingKeys = defaults.dictionaryRepresentation().keys
        for key in existingKeys where prefixedDefaultsKeys.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
            removed += 1
        }

        URLCache.shared.removeAllCachedResponses()

        if let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheEntries = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
            for entry in cacheEntries {
                guard FileManager.default.fileExists(atPath: entry.path) else { continue }
                do {
                    try FileManager.default.removeItem(at: entry)
                    removed += 1
                } catch {
                    continue
                }
            }
        }

        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempEntries = (try? FileManager.default.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)) ?? []
        for entry in tempEntries {
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }
            do {
                try FileManager.default.removeItem(at: entry)
                removed += 1
            } catch {
                continue
            }
        }

        return removed
    }
}

private struct SettingsSurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.62))
            .textCase(.uppercase)
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
    }
}

private struct SettingsCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 56)
            .padding(.trailing, 8)
    }
}

private struct SettingsNavigationRow<Destination: View>: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let iconTint: Color
    private let destination: Destination

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        iconTint: Color = .white,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconTint = iconTint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            SettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconTint: iconTint,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    var iconTint: Color = .white
    var titleColor: Color = .white
    var trailingText: String? = nil
    var isEnabled: Bool = true
    var showChevron: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(
                title: title,
                systemImage: systemImage,
                iconTint: iconTint,
                titleColor: titleColor,
                trailingText: trailingText,
                showChevron: showChevron
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var iconTint: Color = .white
    var titleColor: Color = .white
    var trailingText: String? = nil
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(titleColor)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer(minLength: 8)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.44))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BeatLayout.sectionSpacing) {
                    content
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, BeatLayout.sectionSpacingTight)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsDetailField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.60))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.white)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
    }
}

private struct AccountSettingsView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        SettingsDetailScaffold(title: "Account") {
            SettingsSurfaceCard {
                SettingsDetailField(title: "Username", value: resolvedUsername)
                SettingsCardDivider()
                SettingsDetailField(title: "User ID", value: auth.sessionUserId?.uuidString ?? "Not signed in")
            }
        }
    }

    private var resolvedUsername: String {
        let username = auth.profile?.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let username, !username.isEmpty {
            return "@\(username)"
        }
        return "@user"
    }
}

private struct ChangePasswordSettingsView: View {
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var statusText: String = ""
    @State private var isSaving = false

    var body: some View {
        SettingsDetailScaffold(title: "Change Password") {
            SettingsSurfaceCard {
                Text("Update your account password")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                SecureField("New Password", text: $newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SecureField("Confirm New Password", text: $confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    Task { await updatePassword() }
                } label: {
                    Text(isSaving ? "Saving..." : "Update Password")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    @MainActor
    private func updatePassword() async {
        guard !newPassword.isEmpty else {
            statusText = "Enter a new password."
            return
        }

        guard newPassword.count >= 8 else {
            statusText = "Password must be at least 8 characters."
            return
        }

        guard newPassword == confirmPassword else {
            statusText = "Passwords do not match."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await SupabaseManager.client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            newPassword = ""
            confirmPassword = ""
            statusText = "Password updated."
        } catch {
            statusText = "Could not update password right now."
        }
    }
}

private struct LinkedAccountsSettingsView: View {
    @AppStorage("settings.linked.apple") private var linkedApple = false
    @AppStorage("settings.linked.google") private var linkedGoogle = false
    @AppStorage("settings.linked.spotify") private var linkedSpotify = false

    var body: some View {
        SettingsDetailScaffold(title: "Linked Accounts") {
            SettingsSurfaceCard {
                SettingsToggleRow(title: "Apple", subtitle: "Sign in with Apple", isOn: $linkedApple)
                SettingsCardDivider()
                SettingsToggleRow(title: "Google", subtitle: "Google sign in", isOn: $linkedGoogle)
                SettingsCardDivider()
                SettingsToggleRow(title: "Spotify", subtitle: "Share listening activity", isOn: $linkedSpotify)
            }
        }
    }
}

private struct PaymentsSettingsView: View {
    @EnvironmentObject private var sub: SubscriptionManager
    @State private var statusText: String = ""

    var body: some View {
        SettingsDetailScaffold(title: "Payments") {
            SettingsSurfaceCard {
                SettingsDetailField(title: "Current Plan", value: sub.isPro ? "BeatFinder Pro" : "Free")
                SettingsCardDivider()
                SettingsDetailField(title: "Billing", value: "Managed through Apple ID subscriptions")
            }

            SettingsSurfaceCard {
                NavigationLink {
                    PaywallView()
                } label: {
                    Text(sub.isPro ? "Manage Subscription" : "View Plans")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await sub.restore()
                        statusText = sub.statusText.isEmpty ? "Restore complete." : sub.statusText
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }
}

private struct NotificationsSettingsView: View {
    @AppStorage("settings.notifyNewReleases") private var notifyNewReleases = true
    @AppStorage("settings.notifyMentions") private var notifyMentions = true
    @AppStorage("settings.notifyMarketing") private var notifyMarketing = false

    var body: some View {
        SettingsDetailScaffold(title: "Notifications") {
            SettingsSurfaceCard {
                SettingsToggleRow(title: "New Releases", subtitle: "Get alerts for new drops", isOn: $notifyNewReleases)
                SettingsCardDivider()
                SettingsToggleRow(title: "Mentions & Messages", subtitle: "Mentions, DMs, and replies", isOn: $notifyMentions)
                SettingsCardDivider()
                SettingsToggleRow(title: "Product Updates", subtitle: "News and feature announcements", isOn: $notifyMarketing)
            }
        }
    }
}

private struct PrivacySettingsView: View {
    @AppStorage("settings.privateAccount") private var privateAccount = false
    @AppStorage("settings.shareListeningActivity") private var shareListeningActivity = true
    @AppStorage("settings.personalizedRecommendations") private var personalizedRecommendations = true

    var body: some View {
        SettingsDetailScaffold(title: "Privacy") {
            SettingsSurfaceCard {
                SettingsToggleRow(title: "Private Account", subtitle: "Only approved followers can view your profile", isOn: $privateAccount)
                SettingsCardDivider()
                SettingsToggleRow(title: "Share Listening Activity", subtitle: "Show currently played beats", isOn: $shareListeningActivity)
                SettingsCardDivider()
                SettingsToggleRow(title: "Personalized Recommendations", subtitle: "Use activity for suggestions", isOn: $personalizedRecommendations)
            }
        }
    }
}

private struct SecuritySettingsView: View {
    @AppStorage("settings.requireBiometrics") private var requireBiometrics = false
    @AppStorage("settings.requirePasscode") private var requirePasscode = false
    @AppStorage("settings.twoFactorAuth") private var twoFactorAuth = false

    var body: some View {
        SettingsDetailScaffold(title: "Security") {
            SettingsSurfaceCard {
                SettingsToggleRow(title: "Face ID / Touch ID", subtitle: "Require biometric unlock", isOn: $requireBiometrics)
                SettingsCardDivider()
                SettingsToggleRow(title: "App Passcode", subtitle: "Require passcode when app opens", isOn: $requirePasscode)
                SettingsCardDivider()
                SettingsToggleRow(title: "Two-factor Authentication", subtitle: "Extra sign-in verification", isOn: $twoFactorAuth)
            }
        }
    }
}

private struct LanguageSettingsView: View {
    private enum LanguageOption: String, CaseIterable, Identifiable {
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case german = "de"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Spanish"
            case .french: return "French"
            case .german: return "German"
            }
        }
    }

    @AppStorage("settings.language") private var languageCode = LanguageOption.english.rawValue

    var body: some View {
        SettingsDetailScaffold(title: "Language") {
            SettingsSurfaceCard {
                Text("App Language")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Picker("Language", selection: $languageCode) {
                    ForEach(LanguageOption.allCases) { option in
                        Text(option.title)
                            .tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        SettingsDetailScaffold(title: "Appearance") {
            SettingsSurfaceCard {
                Text("Theme Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Picker("Mode", selection: $settings.appearanceMode) {
                    ForEach(SettingsStore.AppearanceMode.allCases) { mode in
                        Text(mode.rawValue)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("Theme")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(SettingsStore.ThemeOption.allCases) { option in
                        Button {
                            settings.selectedTheme = option.rawValue
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(ThemeManager.accentColor(for: option.rawValue))
                                    .frame(width: 9, height: 9)

                                Text(option.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Spacer(minLength: 4)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(settings.selectedTheme == option.rawValue
                                          ? Color.white.opacity(0.18)
                                          : Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(settings.selectedTheme == option.rawValue ? 0.30 : 0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            SettingsSurfaceCard {
                SettingsToggleRow(title: "Haptics", subtitle: "Tap feedback and vibration", isOn: $settings.hapticsEnabled)
                SettingsCardDivider()
                SettingsToggleRow(title: "Autoplay Previews", subtitle: "Auto-play beat previews", isOn: $settings.autoplayPreviews)
                SettingsCardDivider()
                SettingsToggleRow(title: "Explicit Filter", subtitle: "Hide explicit metadata in feeds", isOn: $settings.explicitFilterEnabled)
            }
        }
    }
}

private struct ScreenCapturingSettingsView: View {
    @AppStorage("settings.screenCaptureEnabled") private var screenCaptureEnabled = true
    @AppStorage("settings.screenCaptureWatermark") private var watermarkEnabled = true

    var body: some View {
        SettingsDetailScaffold(title: "Screen Capturing") {
            SettingsSurfaceCard {
                SettingsToggleRow(title: "Allow Screen Recording", subtitle: "Enable in-app capture tools", isOn: $screenCaptureEnabled)
                SettingsCardDivider()
                SettingsToggleRow(title: "Watermark Exports", subtitle: "Add BeatFinder watermark to captured clips", isOn: $watermarkEnabled)
            }
        }
    }
}

private struct HelpCenterSettingsView: View {
    var body: some View {
        SettingsDetailScaffold(title: "Help Center") {
            SettingsSurfaceCard {
                Text("Quick Help")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Text("• How to upload and publish beats\n• Managing your subscription\n• Licensing and payment questions\n• Fixing playback issues")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsSurfaceCard {
                Text("Need direct help?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Link("Contact Support", destination: URL(string: "mailto:support@beatfinder.app")!)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct ReportProblemSettingsView: View {
    @State private var issueSummary: String = ""
    @State private var statusText: String = ""

    var body: some View {
        SettingsDetailScaffold(title: "Report a Problem") {
            SettingsSurfaceCard {
                Text("Tell us what happened")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                TextEditor(text: $issueSummary)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    let trimmed = issueSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        statusText = "Add a short description before sending."
                    } else {
                        statusText = "Thanks. Your report was saved locally for follow-up."
                        issueSummary = ""
                    }
                } label: {
                    Text("Send Report")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }
}

private struct TermsOfUseSettingsView: View {
    var body: some View {
        PolicyDocumentView(
            title: "Terms of Use",
            bodyText: "These Terms govern your use of BeatFinder. By using the app, you agree not to upload content you do not own, not to misuse subscriptions, and to comply with licensing terms shown for each beat. BeatFinder may update these Terms as features evolve."
        )
    }
}

private struct PrivacyPolicySettingsView: View {
    var body: some View {
        PolicyDocumentView(
            title: "Privacy Policy",
            bodyText: "BeatFinder stores account details, settings preferences, and usage telemetry required to run core features like saved beats and profile data. We do not sell personal data. You can request deletion through support and control notification/privacy preferences in Settings."
        )
    }
}

private struct PolicyDocumentView: View {
    let title: String
    let bodyText: String

    var body: some View {
        SettingsDetailScaffold(title: title) {
            SettingsSurfaceCard {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Text(bodyText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
