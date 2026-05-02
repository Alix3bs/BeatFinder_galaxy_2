import PhotosUI
import SwiftUI

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
}

private struct SettingsDetailScaffold<Content: View>: View {
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
            content
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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

private struct SettingsToggleCard: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
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
}

struct AccountSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @AppStorage("beatfinder.profile.username") private var storedUsername = ""
    @AppStorage("beatfinder.profile.displayName") private var storedDisplayName = ""
    @AppStorage("beatfinder.profile.bio") private var storedBio = ""
    @AppStorage("beatfinder.profile.avatarData") private var storedAvatarData = Data()
    @State private var emailAddress = "Loading…"
    @State private var isEditPresented = false

    var body: some View {
        SettingsDetailScaffold(title: "Account") {
            accountHeader

            SettingsInfoCard(
                title: "Profile",
                subtitle: "Manage the name, photo, and bio other users see in BeatFinder.",
                systemImage: "person.crop.circle"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                settingsLine(title: "Username", value: "@\(resolvedUsername)")
                Divider().overlay(Color.white.opacity(0.06))
                settingsLine(title: "Display Name", value: resolvedDisplayName)
                Divider().overlay(Color.white.opacity(0.06))
                settingsLine(title: "Email", value: emailAddress)
                Divider().overlay(Color.white.opacity(0.06))
                settingsLine(title: "Bio", value: resolvedBio.isEmpty ? "Add a bio" : resolvedBio)
            }

            PrimaryButton(title: "Edit Profile", kind: .light) {
                isEditPresented = true
            }
        }
        .sheet(isPresented: $isEditPresented) {
            AccountProfileEditorSheet()
                .preferredColorScheme(.dark)
                .environmentObject(appState)
                .environmentObject(authStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            emailAddress = await authStore.currentEmail() ?? "Email unavailable"
        }
    }

    private var accountHeader: some View {
        HStack(spacing: 16) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedDisplayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("@\(resolvedUsername)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            Spacer()
        }
    }

    private var avatar: some View {
        Group {
            if let image = UIImage(data: storedAvatarData), !storedAvatarData.isEmpty {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = appState.session.avatarURL {
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

    private var resolvedBio: String {
        storedBio
    }

    private func settingsLine(title: String, value: String) -> some View {
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

private struct AccountProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore

    @AppStorage("beatfinder.profile.username") private var storedUsername = ""
    @AppStorage("beatfinder.profile.displayName") private var storedDisplayName = ""
    @AppStorage("beatfinder.profile.bio") private var storedBio = ""
    @AppStorage("beatfinder.profile.avatarData") private var storedAvatarData = Data()

    @State private var draftUsername = ""
    @State private var draftDisplayName = ""
    @State private var draftBio = ""
    @State private var pickedAvatarItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        avatarPreview

                        photoPicker

                        editorField(title: "Display Name", text: $draftDisplayName, autocapitalization: .words)
                        editorField(title: "Username", text: $draftUsername, autocapitalization: .never)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BeatColors.textSecondary)

                            TextEditor(text: $draftBio)
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 140)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                        }

                        if let errorText, !errorText.isEmpty {
                            Text(errorText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BeatColors.danger)
                        }

                        PrimaryButton(title: isSaving ? "Saving…" : "Save Changes", kind: .light) {
                            Task { await saveChanges() }
                        }
                        .disabled(isSaving || draftUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, BeatLayout.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Edit Profile")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            draftUsername = storedUsername.isEmpty ? appState.session.username : storedUsername
            draftDisplayName = storedDisplayName.isEmpty ? (appState.session.displayName.isEmpty ? draftUsername : appState.session.displayName) : storedDisplayName
            draftBio = storedBio
        }
        .onChange(of: pickedAvatarItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    pendingAvatarImage = image
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private var avatarPreview: some View {
        HStack(spacing: 16) {
            Group {
                if let pendingAvatarImage {
                    Image(uiImage: pendingAvatarImage)
                        .resizable()
                        .scaledToFill()
                } else if let image = UIImage(data: storedAvatarData), !storedAvatarData.isEmpty {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURL = appState.session.avatarURL {
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
                            Text(draftDisplayName.prefix(1).uppercased())
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Profile Photo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("Change the profile image shown across BeatFinder.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $pickedAvatarItem, matching: .images) {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                Text("Choose Profile Image")
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(BeatColors.accentBlueText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(BeatColors.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private func editorField(title: String, text: Binding<String>, autocapitalization: TextInputAutocapitalization?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeatColors.textSecondary)

            TextField(title, text: text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
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

    private func saveChanges() async {
        let cleanedUsername = draftUsername
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let cleanedDisplayName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedUsername.isEmpty else {
            errorText = "Username is required."
            return
        }

        isSaving = true
        errorText = nil

        do {
            if cleanedUsername != appState.session.username {
                try await authStore.updateUsername(cleanedUsername)
            }

            if let pendingAvatarImage {
                try await authStore.uploadAvatar(image: pendingAvatarImage)
                if let jpeg = pendingAvatarImage.jpegData(compressionQuality: 0.9) {
                    storedAvatarData = jpeg
                }
            }

            storedUsername = cleanedUsername
            storedDisplayName = cleanedDisplayName
            storedBio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)

            isSaving = false
            BeatHaptics.success()
            dismiss()
        } catch {
            isSaving = false
            errorText = error.localizedDescription
        }
    }
}

struct VerificationSettingsView: View {
    @AppStorage("settings.verification.applied") private var isApplied = false

    var body: some View {
        SettingsDetailScaffold(title: "Verification") {
            SettingsInfoCard(
                title: "Creator Verification",
                subtitle: "Verification helps listeners trust your profile, posted beats, and public identity.",
                systemImage: "checkmark.seal.fill"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Requirements")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                verificationBullet("Complete your public profile with a photo and username.")
                verificationBullet("Post original beats or creator content consistently.")
                verificationBullet("Follow BeatFinder community and copyright rules.")
                verificationBullet("Keep at least one active social or creator identity linked.")
            }

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isApplied ? "Application Received" : "Not Verified Yet")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Text(isApplied ? "Your creator verification request is in review." : "Apply when your profile and creator history are ready.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isApplied ? "clock.badge.checkmark" : "checkmark.seal")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                }
            }

            PrimaryButton(title: isApplied ? "Continue" : "Apply", kind: .light) {
                isApplied = true
            }
        }
    }

    private func verificationBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(BeatColors.accentBlue)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }
}

struct ChangePasswordSettingsView: View {
    @AppStorage("settings.password.lastChanged") private var lastChanged = ""

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var didSave = false

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var canSave: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && passwordsMatch
    }

    var body: some View {
        SettingsDetailScaffold(title: "Change Password") {
            SettingsInfoCard(
                title: "Update Password",
                subtitle: "Use at least 8 characters and confirm the new password before saving.",
                systemImage: "key.horizontal.fill"
            )

            passwordField("Current Password", text: $currentPassword)
            passwordField("New Password", text: $newPassword)
            passwordField("Confirm Password", text: $confirmPassword)

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("New password and confirmation must match.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.danger)
            }

            if didSave {
                Text("Password details were saved for this session.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.accentBlue)
            }

            PrimaryButton(title: "Save Password", kind: .light) {
                lastChanged = Date().formatted(date: .abbreviated, time: .omitted)
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                didSave = true
            }
            .disabled(!canSave)
        }
    }

    private func passwordField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeatColors.textSecondary)

            SecureField(title, text: text)
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

struct LinkedAccountsSettingsView: View {
    @AppStorage("settings.linked.apple") private var isAppleLinked = true
    @AppStorage("settings.linked.google") private var isGoogleLinked = false
    @AppStorage("settings.linked.email") private var isEmailLinked = true
    @AppStorage("settings.linked.bandlab") private var isBandLabLinked = false

    var body: some View {
        SettingsDetailScaffold(title: "Linked Accounts") {
            linkedRow(title: "Apple", isLinked: $isAppleLinked)
            linkedRow(title: "Google", isLinked: $isGoogleLinked)
            linkedRow(title: "Email", isLinked: $isEmailLinked)
            linkedRow(title: "BandLab", isLinked: $isBandLabLinked)
        }
    }

    private func linkedRow(title: String, isLinked: Binding<Bool>) -> some View {
        SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(isLinked.wrappedValue ? "Linked" : "Not linked")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BeatColors.textSecondary)
                }

                Spacer()

                Button(isLinked.wrappedValue ? "Disconnect" : "Connect") {
                    isLinked.wrappedValue.toggle()
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
                    subtitle: "Like a beat in Explore and it will show up here for quick access.",
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
    @AppStorage("settings.notifications.push") private var pushNotifications = true
    @AppStorage("settings.notifications.email") private var emailNotifications = false
    @AppStorage("settings.notifications.recommendations") private var beatRecommendations = true
    @AppStorage("settings.notifications.releases") private var newReleases = true
    @AppStorage("settings.notifications.purchases") private var purchases = true
    @AppStorage("settings.notifications.membership") private var membershipUpdates = true
    @AppStorage("settings.notifications.creatorActivity") private var creatorActivity = true
    @AppStorage("settings.notifications.announcements") private var appAnnouncements = false

    var body: some View {
        SettingsDetailScaffold(title: "Notifications") {
            SettingsToggleCard(title: "Push Notifications", subtitle: "General alerts sent to this device.", isOn: $pushNotifications)
            SettingsToggleCard(title: "Email Notifications", subtitle: "Receive important updates by email.", isOn: $emailNotifications)
            SettingsToggleCard(title: "Beat Recommendations", subtitle: "Suggested beats and playlists based on your activity.", isOn: $beatRecommendations)
            SettingsToggleCard(title: "New Releases", subtitle: "Fresh drops from followed creators and releases.", isOn: $newReleases)
            SettingsToggleCard(title: "Purchases", subtitle: "Receipts and order updates.", isOn: $purchases)
            SettingsToggleCard(title: "Membership Updates", subtitle: "Renewals, plan changes, and billing reminders.", isOn: $membershipUpdates)
            SettingsToggleCard(title: "Creator Activity", subtitle: "Profile updates and creator actions.", isOn: $creatorActivity)
            SettingsToggleCard(title: "App Announcements", subtitle: "Product updates and releases from BeatFinder.", isOn: $appAnnouncements)
        }
    }
}

struct PrivacySettingsView: View {
    @AppStorage("settings.privacy.profileVisibility") private var profileVisibility = "Public"
    @AppStorage("settings.privacy.showActivity") private var showActivity = true
    @AppStorage("settings.privacy.showLikes") private var showLikedBeats = false
    @AppStorage("settings.privacy.privateAccount") private var privateAccount = false

    var body: some View {
        SettingsDetailScaffold(title: "Privacy") {
            SettingsInfoCard(
                title: "Control what people can see",
                subtitle: "These settings affect your public profile, activity, and liked content.",
                systemImage: "lock.fill"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("Profile Visibility")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Picker("Profile Visibility", selection: $profileVisibility) {
                    Text("Public").tag("Public")
                    Text("Followers Only").tag("Followers Only")
                    Text("Private").tag("Private")
                }
                .pickerStyle(.segmented)
            }

            SettingsToggleCard(title: "Show Activity", subtitle: "Display your activity and recent actions.", isOn: $showActivity)
            SettingsToggleCard(title: "Show Liked Beats", subtitle: "Allow others to see liked beats on your profile.", isOn: $showLikedBeats)
            SettingsToggleCard(title: "Private Account", subtitle: "Require approval before others can follow you.", isOn: $privateAccount)
        }
    }
}

struct SecuritySettingsView: View {
    @AppStorage("settings.security.twoFactor") private var twoFactorEnabled = false
    @AppStorage("settings.security.passwordLastChanged") private var passwordLastChanged = ""
    @State private var isSignOutOtherSessionsPresented = false
    @State private var signedOutOtherSessions = false

    var body: some View {
        SettingsDetailScaffold(title: "Security") {
            SettingsToggleCard(title: "Two-Factor Authentication", subtitle: "Add a second step when signing in.", isOn: $twoFactorEnabled)

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                securityRow(title: "Login Activity", value: "2 recent logins")
                Divider().overlay(Color.white.opacity(0.06))
                securityRow(title: "Trusted Devices", value: "This iPad")
                Divider().overlay(Color.white.opacity(0.06))
                securityRow(title: "Password Last Changed", value: passwordLastChanged.isEmpty ? "Not available" : passwordLastChanged)
            }

            Button {
                isSignOutOtherSessionsPresented = true
            } label: {
                SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sign Out Other Sessions")
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
        .confirmationDialog("Sign out other sessions?", isPresented: $isSignOutOtherSessionsPresented, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out Sessions", role: .destructive) {
                signedOutOtherSessions = true
            }
        } message: {
            Text("Your other active sessions will be closed.")
        }
    }

    private func securityRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }
}

struct LanguageSettingsView: View {
    @AppStorage("settings.language.selected") private var selectedLanguage = "English"

    private let languages = ["English", "Spanish", "French", "German", "Portuguese", "Japanese"]

    var body: some View {
        SettingsDetailScaffold(title: "Language") {
            ForEach(languages, id: \.self) { language in
                Button {
                    selectedLanguage = language
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
        }
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        SettingsDetailScaffold(title: "Appearance") {
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

            SettingsInfoCard(
                title: "Display Note",
                subtitle: "BeatFinder currently ships with dark mode as the primary visual system, even when Light or System is selected.",
                systemImage: "moon.stars.fill"
            )
        }
    }
}

struct ScreenCapturingSettingsView: View {
    @AppStorage("settings.capture.allowScreenshots") private var allowScreenshots = true
    @AppStorage("settings.capture.hideSensitiveData") private var hideSensitiveData = false

    var body: some View {
        SettingsDetailScaffold(title: "Screen Capturing") {
            SettingsInfoCard(
                title: "Recording Privacy",
                subtitle: "Choose whether screenshots and screen recordings should hide sensitive BeatFinder details.",
                systemImage: "record.circle.fill"
            )

            SettingsToggleCard(title: "Allow Screenshots", subtitle: "Permit standard device screenshots while using the app.", isOn: $allowScreenshots)
            SettingsToggleCard(title: "Hide Sensitive Data During Recording", subtitle: "Mask certain information while the screen is recorded.", isOn: $hideSensitiveData)
        }
    }
}

struct HelpCenterSettingsView: View {
    @State private var expandedTopic: String?

    private let topics: [(String, String)] = [
        ("Account", "Manage your profile, sign-in, and creator settings."),
        ("Uploads", "Questions about file import, links, and source handling."),
        ("Subscriptions", "Membership plans, renewals, and restoring purchases."),
        ("Matching", "BeatFinder analysis, saved results, and accuracy guidance."),
        ("Saved Beats", "How to save, reopen, and organize beats.")
    ]

    var body: some View {
        SettingsDetailScaffold(title: "Help Center") {
            ForEach(topics, id: \.0) { topic, bodyText in
                Button {
                    expandedTopic = expandedTopic == topic ? nil : topic
                } label: {
                    SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(topic)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()

                                Image(systemName: expandedTopic == topic ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(BeatColors.textSecondary)
                            }

                            if expandedTopic == topic {
                                Text(bodyText)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(BeatColors.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(BeatPressableButtonStyle())
            }

            PrimaryButton(title: "Contact Support", kind: .light) {}
        }
    }
}

struct ReportProblemSettingsView: View {
    @State private var selectedCategory = "Bug"
    @State private var description = ""
    @State private var submitted = false

    private let categories = ["Bug", "Payments", "Matching", "Profile", "Other"]

    var body: some View {
        SettingsDetailScaffold(title: "Report a Problem") {
            SettingsInfoCard(
                title: "Tell us what happened",
                subtitle: "Add a category, describe the issue, and submit it for review.",
                systemImage: "exclamationmark.bubble.fill"
            )

            SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                Text("Category")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.textSecondary)

                TextEditor(text: $description)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            }

            SectionCard(cornerRadius: 20, padding: 16, fill: Color.white.opacity(0.045), strokeOpacity: 0.07) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attach Screenshot")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Attachment support is queued for the next backend pass.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BeatColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                }
            }

            if submitted {
                Text("Your report was submitted locally and is ready for backend delivery.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeatColors.accentBlue)
            }

            PrimaryButton(title: "Submit", kind: .light) {
                submitted = true
                description = ""
            }
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct LegalDocumentSettingsView: View {
    let title: String
    let intro: String

    var body: some View {
        SettingsDetailScaffold(title: title) {
            Text(intro)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)

            Text(legalBody)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .textSelection(.enabled)
        }
    }

    private var legalBody: String {
        """
        1. BeatFinder provides beat discovery, matching, saving, and creator tools within the app.

        2. Your account information and preferences are used to personalize beat recommendations, saved content, and creator-facing features.

        3. You are responsible for the content you upload, share, and save, including any lyrics, descriptions, links, or creator posts.

        4. Membership features, billing, and restoration depend on active subscription entitlements and may vary by plan.

        5. Saved beats, likes, and lyric notes may be stored locally on the device and synced to supported backend services when available.

        6. BeatFinder may update these terms and policies as production services expand. Continued use of the app means you accept the latest version.
        """
    }
}

struct BandLabTestersSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsDetailScaffold(title: "Join BandLab Testers") {
            SettingsInfoCard(
                title: "Tester Access",
                subtitle: "Apply for early product experiments, beta workflows, and creator feedback programs.",
                systemImage: "testtube.2"
            )

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                Text("BandLab Testers preview upcoming creator features, membership tools, and publishing improvements before public release.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            PrimaryButton(title: "Join / Apply", kind: .light) {
                if let url = URL(string: "https://www.bandlab.com") {
                    openURL(url)
                }
            }
        }
    }
}
