import SwiftUI
import PhotosUI
import UIKit

struct MyStudioView: View {

    enum ProfileTab: String, CaseIterable {
        case activity = "Activity"
        case music = "Music"
        case videos = "Videos"
        case gear = "Gear"
        case bands = "Bands"
    }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var sub: SubscriptionManager

    @State private var profileTab: ProfileTab = .activity

    // Local UI state
    @State private var showEditUsername = false
    @State private var showApplyVerified = false
    @State private var showSubscription = false
    @State private var showSettings = false

    // Avatar picker
    @State private var pickedPfpItem: PhotosPickerItem?
    @State private var localPfpImage: UIImage? = nil
    @State private var avatarURL: URL? = nil

    // Loading flags
    @State private var isSavingUsername = false
    @State private var isUploadingAvatar = false
    @State private var errorText: String?

    // Posted beat preview
    @State private var postedBeatTitle: String = ""
    @State private var postedBeatArtworkImage: UIImage? = nil

    private let postedBeatTitleKey = "beatfinder.postedBeatTitle"
    private let postedBeatArtworkDataKey = "beatfinder.postedBeatArtworkData"

    // Derived display strings
    private var displayUsername: String {
        auth.profile?.username?.isEmpty == false ? (auth.profile?.username ?? "") : "Your Studio"
    }

    private var displayHandle: String {
        let u = auth.profile?.username ?? "user"
        return "@\(u)"
    }

    private var hasPostedBeat: Bool {
        !postedBeatTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || postedBeatArtworkImage != nil
    }

    private var visiblePostedBeatTitle: String {
        let cleaned = postedBeatTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "(untitled)" : cleaned
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BeatLayout.sectionSpacing) {

                    header
                        .padding(.top, 8)

                    verifiedCard

                    tabs

                    tabContent

                    if hasPostedBeat {
                        postedBeatCard
                    }

                    Spacer(minLength: 72)
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.bottom, 120)
            }

            // lightweight loading overlay
            if isUploadingAvatar || isSavingUsername {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(isUploadingAvatar ? "Uploading photo..." : "Saving...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BeatLayout.cornerRadius, style: .continuous))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            topRightBar
        }
        .sheet(isPresented: $showEditUsername) {
            EditUsernameSheet(
                initialUsername: auth.profile?.username ?? "",
                onSave: { newUsername in
                    await saveUsername(newUsername)
                }
            )
            .presentationDetents([.height(250)])
            .preferredColorScheme(settings.preferredColorScheme)
        }
        .sheet(isPresented: $showApplyVerified) {
            VerifiedInfoSheet()
                .presentationDetents([.height(260)])
                .preferredColorScheme(settings.preferredColorScheme)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
            .environmentObject(auth)
            .environmentObject(settings)
            .environmentObject(sub)
            .presentationDetents([.large])
            .preferredColorScheme(settings.preferredColorScheme)
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                PaywallView()
            }
            .environmentObject(sub)
            .environmentObject(settings)
            .presentationDetents([.large])
            .preferredColorScheme(settings.preferredColorScheme)
        }
        .onAppear {
            Task {
                await auth.fetchProfile()
                await refreshSignedAvatarURL()
            }
            loadPostedBeatPreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadPostedBeatPreview()
        }
        .onChange(of: auth.profile?.avatar_url) { _, _ in
            Task { await refreshSignedAvatarURL() }
        }
        .onChange(of: pickedPfpItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleAvatarPick(newItem) }
        }
    }

    // MARK: - Top right bar

    private var topRightBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 10) {
                Button {
                    showSubscription = true
                } label: {
                    Image(systemName: "crown")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, BeatLayout.screenHorizontal)
            .padding(.top, 6)
        }
        .background(Color.black.opacity(0.001))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {

            PhotosPicker(selection: $pickedPfpItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 74, height: 74)

                    // Priority:
                    // 1) local picked image (instant feedback)
                    // 2) signed URL image (from storage)
                    // 3) placeholder
                    if let ui = localPfpImage {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                    } else if let avatarURL {
                        AsyncImage(url: avatarURL) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                Color.white.opacity(0.02)
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            }
                        }
                        .frame(width: 74, height: 74)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(displayUsername)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer()

                    Button {
                        showEditUsername = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text(displayHandle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))

                profileStats

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.top, 4)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var profileStats: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                stat("5", "Followers")
                Text("•").foregroundStyle(.white.opacity(0.35))
                stat("2", "Following")
                Text("•").foregroundStyle(.white.opacity(0.35))
                stat("0", "Plays")
            }

            VStack(alignment: .leading, spacing: 6) {
                stat("5", "Followers")
                stat("2", "Following")
                stat("0", "Plays")
            }
        }
    }

    // MARK: - Verified card

    private var verifiedCard: some View {
        Button {
            showApplyVerified = true
        } label: {
            SectionCard {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply for a Verified badge")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Gain credibility and trust")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tabs

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    let isOn = (tab == profileTab)
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isOn ? .white : .white.opacity(0.55))

                        Capsule()
                            .fill(isOn ? Color.white : Color.clear)
                            .frame(width: 28, height: 3)
                    }
                    .padding(.vertical, 6)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            profileTab = tab
                        }
                    }
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var tabContent: some View {
        switch profileTab {
        case .activity:
            placeholder("No activity yet")
        case .music:
            placeholder("No beats posted yet")
        case .videos:
            placeholder("No videos yet")
        case .gear:
            placeholder("No gear listed yet")
        case .bands:
            placeholder("No bands yet")
        }
    }

    private func placeholder(_ text: String) -> some View {
        SectionCard(fill: Color.white.opacity(0.04), strokeOpacity: 0.10) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var postedBeatCard: some View {
        SectionCard {
            Text("Latest Posted Beat")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let postedBeatArtworkImage {
                                Image(uiImage: postedBeatArtworkImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.white.opacity(0.08)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.45))
                                    )
                            }
                        }
                        .frame(width: 170, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.80)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 170, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Text(visiblePostedBeatTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .padding(10)
                    }

                    Text("Shows your most recently posted beat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Actions

    private func saveUsername(_ username: String) async -> Bool {
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            errorText = "Username cannot be empty."
            return false
        }
        errorText = nil
        isSavingUsername = true
        defer { isSavingUsername = false }
        do {
            try await auth.updateUsername(cleaned)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func handleAvatarPick(_ item: PhotosPickerItem) async {
        errorText = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else { return }

            await MainActor.run { localPfpImage = img } // instant UI
            isUploadingAvatar = true
            try await auth.uploadAvatar(image: img)
            await refreshSignedAvatarURL()
            isUploadingAvatar = false
        } catch {
            isUploadingAvatar = false
            errorText = error.localizedDescription
        }
    }

    private func refreshSignedAvatarURL() async {
        avatarURL = await auth.signedAvatarURL()
    }

    private func loadPostedBeatPreview() {
        postedBeatTitle = UserDefaults.standard.string(forKey: postedBeatTitleKey) ?? ""

        guard let data = UserDefaults.standard.data(forKey: postedBeatArtworkDataKey),
              let image = UIImage(data: data) else {
            postedBeatArtworkImage = nil
            return
        }
        postedBeatArtworkImage = image
    }
}

// MARK: - Sheets

private struct EditUsernameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialUsername: String
    let onSave: (String) async -> Bool

    @State private var draft: String = ""
    @State private var isSaving = false
    @State private var localError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit username")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                TextField("Username", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous))
                    .foregroundStyle(.white)

                PrimaryButton(title: isSaving ? "Saving..." : "Save") {
                    localError = nil
                    isSaving = true
                    Task {
                        let didSave = await onSave(draft)
                        await MainActor.run {
                            isSaving = false
                            if didSave {
                                dismiss()
                            } else {
                                localError = "Could not save username."
                            }
                        }
                    }
                }
                .disabled(isSaving)

                if let localError {
                    Text(localError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                }

                Spacer()
            }
            .padding(18)
        }
        .onAppear { draft = initialUsername }
    }
}

private struct VerifiedInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("Verified badge")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Placeholder flow. Later you'll submit your profile + ID and we'll review it.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
    }
}

#Preview {
    NavigationStack {
        MyStudioView()
            .environmentObject(AuthStore())
            .environmentObject(SettingsStore())
            .environmentObject(SubscriptionManager())
    }
    .preferredColorScheme(.dark)
}
