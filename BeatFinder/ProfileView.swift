import Combine
import Foundation
import PhotosUI
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    func displayName(from session: SessionState) -> String {
        session.displayName.isEmpty ? "mrbub" : session.displayName
    }

    func handle(from session: SessionState) -> String {
        "@\(session.username.isEmpty ? "mrbub" : session.username)"
    }

    func statText(for session: SessionState) -> String {
        if session.isAuthenticated {
            return "5 Followers  •  2 Following  •  0 Plays"
        }
        return "0 Followers  •  0 Following  •  0 Plays"
    }
}
import Foundation

@MainActor
final class WalletViewModel: ObservableObject {
    struct Activity: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let amount: String
    }

    let cardholderName = "TRAY3BEATS"
    let cardNumber = "4242  4800  9800  1123"
    let balance = "$2,450.00"
    let activity: [Activity] = [
        Activity(title: "Beat payout", subtitle: "Today · 2:45 PM", amount: "+$45.00"),
        Activity(title: "Membership renewal", subtitle: "Yesterday", amount: "-$9.99"),
        Activity(title: "Transfer to bank", subtitle: "Feb 24", amount: "-$120.00")
    ]
}
import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = WalletViewModel()
    @AppStorage("beatfinder.wallet.lastAddedCardSuffix") private var lastAddedCardSuffix = ""
    @AppStorage("beatfinder.wallet.lastAddedCardNetwork") private var lastAddedCardNetwork = ""
    @State private var isAddCardPresented = false
    @State private var cardNumber = ""
    @State private var expiration = ""
    @State private var securityCode = ""
    @State private var selectedNetwork = "Visa"
    @State private var walletFeedbackMessage: String?
    @FocusState private var focusedAddCardField: AddCardField?

    private enum AddCardField {
        case cardNumber
        case expiration
        case securityCode
    }

    private let supportedNetworks = ["Visa", "Mastercard", "Amex", "Discover"]

    var body: some View {
        ZStack {
            ScreenContainer(
                spacing: 22,
                topPadding: 12,
                bottomPadding: 28,
                maxWidthStyle: .standard,
                includeTabBarClearance: true
            ) {
                Color.black
            } content: {
                TiltCardView {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.71, green: 0.57, blue: 0.99),
                                        Color(red: 0.59, green: 0.41, blue: 0.96),
                                        Color(red: 0.32, green: 0.20, blue: 0.58)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.16),
                                                Color.clear,
                                                Color.black.opacity(0.18)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: horizontalSizeClass == .regular ? 220 : 160, height: horizontalSizeClass == .regular ? 220 : 160)
                            .blur(radius: 56)
                            .offset(x: -34, y: -54)

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("BeatFinder Wallet")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.92))

                                    Text("Available balance")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.68))
                                }

                                Spacer()

                                Image(systemName: "wave.3.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .padding(12)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }

                            Text(viewModel.balance)
                                .font(.system(size: horizontalSizeClass == .regular ? 36 : 32, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer(minLength: 0)

                            Text(maskedCardNumber)
                                .font(.system(size: horizontalSizeClass == .regular ? 21 : 19, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.96))

                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cardholder")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text(resolvedCardholderName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Status")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text("Active")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                            }
                        }
                        .padding(horizontalSizeClass == .regular ? 26 : 22)
                    }
                    .frame(height: horizontalSizeClass == .regular ? 264 : 232)
                }
                .accessibilityIdentifier("wallet.topCard")

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cards & Payments")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Manage payment methods and keep wallet details current.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()

                    Button {
                        BeatHaptics.tap()
                        withAnimation(MotionTokens.mediumEase) {
                            isAddCardPresented = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Add Card")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(BeatColors.accentBlueText)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(BeatColors.accentBlue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Recent Activity")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(spacing: 14) {
                        ForEach(viewModel.activity) { item in
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.06))

                                    Image(systemName: transactionIcon(for: item))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(item.amount.hasPrefix("+") ? BeatColors.positive : BeatColors.accentBlue)
                                }
                                .frame(width: 50, height: 50)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(item.subtitle)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.62))
                                }

                                Spacer()

                                Text(item.amount)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(item.amount.hasPrefix("+") ? Color(red: 0.57, green: 0.88, blue: 0.67) : .white.opacity(0.9))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.045))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(.top, 2)
            }

            if isAddCardPresented {
                addCardOverlay
            }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let walletFeedbackMessage {
                walletToast(message: walletFeedbackMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(MotionTokens.fastEase, value: isAddCardPresented)
        .animation(MotionTokens.fastEase, value: walletFeedbackMessage)
    }

    private var resolvedCardholderName: String {
        if !appState.session.displayName.isEmpty {
            return appState.session.displayName.uppercased()
        }
        if !appState.session.username.isEmpty {
            return appState.session.username.uppercased()
        }
        return viewModel.cardholderName
    }

    private var maskedCardNumber: String {
        "••••  4800  9800  1123"
    }

    private func transactionIcon(for item: WalletViewModel.Activity) -> String {
        if item.amount.hasPrefix("+") {
            return "arrow.down.left"
        }
        if item.title.lowercased().contains("membership") {
            return "sparkles"
        }
        return "building.columns.fill"
    }

    private var addCardOverlay: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissAddCard()
                    }

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add Card")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Enter your card details below.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    VStack(spacing: 16) {
                        addCardField(
                            title: "Card Number",
                            placeholder: "1234 5678 9012 3456",
                            text: $cardNumber,
                            field: .cardNumber,
                            keyboardType: .numberPad
                        )
                        .onChange(of: cardNumber) { _, newValue in
                            cardNumber = formattedCardNumber(from: newValue)
                        }

                        HStack(spacing: 14) {
                            addCardField(
                                title: "Expiration",
                                placeholder: "MM/YY",
                                text: $expiration,
                                field: .expiration,
                                keyboardType: .numberPad
                            )
                            .onChange(of: expiration) { _, newValue in
                                expiration = formattedExpiration(from: newValue)
                            }

                            secureAddCardField(
                                title: "Security Code",
                                placeholder: "CVV",
                                text: $securityCode,
                                field: .securityCode
                            )
                            .onChange(of: securityCode) { _, newValue in
                                securityCode = String(newValue.filter(\.isNumber).prefix(4))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Network")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            Menu {
                                ForEach(supportedNetworks, id: \.self) { network in
                                    Button(network) {
                                        selectedNetwork = network
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedNetwork)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(BeatColors.accentBlue)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            dismissAddCard()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.07))
                                )
                        }
                        .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.92))

                        Button {
                            saveCard()
                        } label: {
                            Text("Save Card")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(BeatColors.accentBlueText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(BeatColors.accentBlue)
                                )
                        }
                        .buttonStyle(BeatPressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.92))
                        .disabled(!isAddCardFormValid)
                        .opacity(isAddCardFormValid ? 1 : 0.56)
                    }
                }
                .padding(horizontalSizeClass == .regular ? 28 : 24)
                .frame(width: min(proxy.size.width - 36, horizontalSizeClass == .regular ? 500 : 420))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(red: 0.125, green: 0.133, blue: 0.153))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.04),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.34), radius: 24, x: 0, y: 16)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func addCardField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: AddCardField,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.28)))
                .focused($focusedAddCardField, equals: field)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(addCardFieldBackground(for: field))
        }
    }

    private func secureAddCardField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: AddCardField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.28)))
                .focused($focusedAddCardField, equals: field)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(addCardFieldBackground(for: field))
        }
    }

    private func addCardFieldBackground(for field: AddCardField) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        focusedAddCardField == field ? BeatColors.accentBlue.opacity(0.72) : Color.white.opacity(0.07),
                        lineWidth: 1
                    )
            )
    }

    private var isAddCardFormValid: Bool {
        let digits = cardNumber.filter(\.isNumber)
        let expirationDigits = expiration.filter(\.isNumber)
        return digits.count >= 16 && expirationDigits.count == 4 && securityCode.count >= 3 && !selectedNetwork.isEmpty
    }

    private func formattedCardNumber(from value: String) -> String {
        let digits = String(value.filter(\.isNumber).prefix(16))
        return stride(from: 0, to: digits.count, by: 4).map { index in
            let start = digits.index(digits.startIndex, offsetBy: index)
            let end = digits.index(start, offsetBy: min(4, digits.count - index))
            return String(digits[start..<end])
        }
        .joined(separator: " ")
    }

    private func formattedExpiration(from value: String) -> String {
        let digits = String(value.filter(\.isNumber).prefix(4))
        if digits.count <= 2 {
            return digits
        }
        let month = digits.prefix(2)
        let year = digits.suffix(digits.count - 2)
        return "\(month)/\(year)"
    }

    private func dismissAddCard() {
        focusedAddCardField = nil
        withAnimation(MotionTokens.mediumEase) {
            isAddCardPresented = false
        }
    }

    private func saveCard() {
        guard isAddCardFormValid else { return }

        lastAddedCardSuffix = String(cardNumber.filter(\.isNumber).suffix(4))
        lastAddedCardNetwork = selectedNetwork
        BeatHaptics.success()
        dismissAddCard()
        presentWalletToast("Card added")
        resetAddCardForm()
    }

    private func resetAddCardForm() {
        cardNumber = ""
        expiration = ""
        securityCode = ""
        selectedNetwork = supportedNetworks[0]
    }

    private func presentWalletToast(_ message: String) {
        walletFeedbackMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard walletFeedbackMessage == message else { return }
            walletFeedbackMessage = nil
        }
    }

    private func walletToast(message: String) -> some View {
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
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var messagingStore: MessagingStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let scrollToTopToken: Int
    @StateObject private var viewModel = ProfileViewModel()
    @AppStorage("beatfinder.profile.username") private var storedUsername = ""
    @AppStorage("beatfinder.profile.avatarData") private var storedAvatarData = Data()
    @AppStorage("beatfinder.profile.bannerData") private var storedBannerData = Data()
    @State private var selectedSection = "Activity"
    @State private var isEditProfilePresented = false
    @State private var isInboxPresented = false
    @State private var activePlaceholder: PlaceholderDestination?
    @State private var selectedBeat: BeatResultModel?

    private let sections = ["Activity", "Music", "Videos", "Gear", "Bands"]
    private let userBeatPosts: [ProfileBeatPost] = [
        ProfileBeatPost(
            title: "Midnight Loop",
            subtitle: "R&B",
            imageName: nil,
            result: BeatResultModel(id: "studio-1", title: "Midnight Loop", artist: "Tray3Beats", bpm: 124, genre: "R&B", releaseDate: Date(), artworkName: nil, youtubeVideoID: "dQw4w9WgXcQ", youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        ),
        ProfileBeatPost(
            title: "Blue Ember",
            subtitle: "Trap",
            imageName: nil,
            result: BeatResultModel(id: "studio-2", title: "Blue Ember", artist: "Tray3Beats", bpm: 136, genre: "Trap", releaseDate: Date().addingTimeInterval(-86_400 * 3), artworkName: nil, youtubeVideoID: "kJQP7kiw5Fk", youtubeWatchURLString: "https://www.youtube.com/watch?v=kJQP7kiw5Fk")
        ),
        ProfileBeatPost(
            title: "Night Shift",
            subtitle: "Soul Trap",
            imageName: nil,
            result: BeatResultModel(id: "studio-3", title: "Night Shift", artist: "Tray3Beats", bpm: 140, genre: "Soul Trap", releaseDate: Date().addingTimeInterval(-86_400 * 9), artworkName: nil, youtubeVideoID: "JGwWNGJdvx8", youtubeWatchURLString: "https://www.youtube.com/watch?v=JGwWNGJdvx8")
        )
    ]
    private let videoPosts: [ProfileBeatPost] = [
        ProfileBeatPost(
            title: "Studio Preview",
            subtitle: "Video",
            imageName: nil,
            result: BeatResultModel(id: "studio-4", title: "Studio Preview", artist: "Tray3Beats", bpm: 120, genre: "Video", releaseDate: Date(), artworkName: nil, youtubeVideoID: "2Vv-BfVoq4g", youtubeWatchURLString: "https://www.youtube.com/watch?v=2Vv-BfVoq4g")
        ),
        ProfileBeatPost(
            title: "Session Export",
            subtitle: "Video",
            imageName: nil,
            result: BeatResultModel(id: "studio-5", title: "Session Export", artist: "Tray3Beats", bpm: 118, genre: "Video", releaseDate: Date(), artworkName: nil, youtubeVideoID: "dQw4w9WgXcQ", youtubeWatchURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        )
    ]
    private let gearPosts: [ProfileBeatPost] = [
        ProfileBeatPost(
            title: "MPC Live",
            subtitle: "Gear",
            imageName: nil,
            result: BeatResultModel(id: "studio-6", title: "MPC Live Jam", artist: "Tray3Beats", bpm: 112, genre: "Gear", releaseDate: Date(), artworkName: nil, youtubeVideoID: "JGwWNGJdvx8", youtubeWatchURLString: "https://www.youtube.com/watch?v=JGwWNGJdvx8")
        )
    ]

    var body: some View {
        ScreenContainer(
            spacing: 16,
            topPadding: 12,
            bottomPadding: 28,
            maxWidthStyle: .wide,
            includeTabBarClearance: true,
            scrollToTopToken: scrollToTopToken
        ) {
            Color.black
        } content: {
            profileHero
            sectionTabs
            sectionContent
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isEditProfilePresented) {
            EditStudioProfileSheet(
                authStore: appState.authStore,
                currentUsername: editableUsername,
                currentAvatarURL: appState.session.avatarURL,
                currentAvatarData: storedAvatarData.isEmpty ? nil : storedAvatarData,
                currentBannerData: storedBannerData.isEmpty ? nil : storedBannerData,
                onSave: { username, avatarData, bannerData in
                    storedUsername = username
                    storedAvatarData = avatarData ?? Data()
                    storedBannerData = bannerData ?? Data()
                }
            )
            .preferredColorScheme(.dark)
            .presentationDetents([.height(500), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $activePlaceholder) { destination in
            PlaceholderDetailView(destination: destination)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isInboxPresented) {
            NavigationStack {
                DirectMessageInboxView()
                    .environmentObject(messagingStore)
            }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedBeat != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedBeat = nil
                    }
                }
            )
        ) {
            NavigationStack {
                Group {
                    if let selectedBeat {
                        UploadResultView(model: selectedBeat, sourceContext: .explore)
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var profileHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    banner
                        .frame(height: horizontalSizeClass == .regular ? 236 : 196)

                    avatar
                        .padding(.leading, 20)
                        .offset(y: 42)
                }

                HStack(spacing: 10) {
                    profileIconButton(systemImage: "crown.fill", isAccent: true) {
                        appState.presentSubscription()
                    }
                    .accessibilityIdentifier("profile.crownButton")

                    profileIconButton(systemImage: "bubble.left.and.bubble.right.fill") {
                        isInboxPresented = true
                    }
                    .accessibilityIdentifier("profile.messageButton")

                    profileIconButton(systemImage: "gearshape.fill") {
                        appState.openSettings()
                    }
                    .accessibilityIdentifier("profile.settingsButton")

                    profileIconButton(systemImage: "square.and.pencil") {
                        isEditProfilePresented = true
                    }
                }
                .padding(16)
            }
            .padding(.bottom, 42)

            Button {
                BeatHaptics.tap()
                isEditProfilePresented = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(editableDisplayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text(editableHandle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BeatColors.textSecondary)
                }
            }
            .buttonStyle(BeatPressableButtonStyle())

            statButtons
        }
    }

    private var avatar: some View {
        Button {
            BeatHaptics.tap()
            isEditProfilePresented = true
        } label: {
            Group {
                if let storedAvatarImage {
                    Image(uiImage: storedAvatarImage)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURL = appState.session.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                } else {
                    Circle()
                        .fill(BeatColors.surfaceSecondary)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                        )
                }
            }
            .frame(width: horizontalSizeClass == .regular ? 104 : 88, height: horizontalSizeClass == .regular ? 104 : 88)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var banner: some View {
        ZStack {
            if let storedBannerImage {
                Image(uiImage: storedBannerImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        BeatColors.subscriptionDeepNavy,
                        BeatColors.surfaceSecondary,
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 28 : 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 28 : 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 26) {
                ForEach(sections, id: \.self) { section in
                    Button {
                        BeatHaptics.tap()
                        selectedSection = section
                    } label: {
                        VStack(spacing: 10) {
                            Text(section)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.60))

                            Capsule()
                                .fill(selectedSection == section ? Color.white : Color.clear)
                                .frame(width: 30, height: 3)
                        }
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedSection)
    }

    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !postsForSelectedSection.isEmpty {
                Text("Posted Beats")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            LazyVGrid(columns: profilePostColumns, spacing: 14) {
                ForEach(postsForSelectedSection) { post in
                    Button {
                        BeatHaptics.tap()
                        selectedBeat = post.result
                    } label: {
                        ProfileBeatPostCard(post: post)
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }
            }

            Button {
                BeatHaptics.tap()
                activePlaceholder = PlaceholderDestination(
                    id: "profile.create-first-post",
                    title: "Create First Post",
                    message: "Start your first post from here when the publishing composer is ready.",
                    detail: "This placeholder keeps the activity row actionable until the composer ships.",
                    systemImage: "square.and.pencil"
                )
            } label: {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .frame(height: 54)
                    .overlay(alignment: .leading) {
                        Text(emptyStateText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))
                            .padding(.horizontal, 18)
                    }
            }
            .buttonStyle(BeatPressableButtonStyle())
        }
    }

    private var statButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                statButton(title: "Followers", value: "5")
                statButton(title: "Following", value: "2")
                statButton(title: "Plays", value: "0")
            }

            VStack(alignment: .leading, spacing: 10) {
                statButton(title: "Followers", value: "5")
                statButton(title: "Following", value: "2")
                statButton(title: "Plays", value: "0")
            }
        }
    }

    private var emptyStateText: String {
        switch selectedSection {
        case "Activity":
            return "No activity yet"
        case "Music":
            return "No music uploaded yet"
        case "Videos":
            return "No videos yet"
        case "Gear":
            return "No gear listed yet"
        case "Bands":
            return "No bands added yet"
        default:
            return "Nothing here yet"
        }
    }

    private var postsForSelectedSection: [ProfileBeatPost] {
        switch selectedSection {
        case "Music":
            return userBeatPosts
        case "Videos":
            return videoPosts
        case "Gear":
            return gearPosts
        case "Bands":
            return []
        default:
            return userBeatPosts
        }
    }

    private var profilePostColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        }
        return [GridItem(.flexible(), spacing: 14)]
    }

    private func profileIconButton(systemImage: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            BeatHaptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isAccent ? BeatColors.accentBlueText : .white)
                .frame(width: horizontalSizeClass == .regular ? 52 : 44, height: horizontalSizeClass == .regular ? 52 : 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isAccent ? BeatColors.accentBlue : BeatColors.surfaceSecondary)
                )
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private func statButton(title: String, value: String) -> some View {
        Button {
            BeatHaptics.tap()
            activePlaceholder = PlaceholderDestination(
                id: "profile.stat.\(title.lowercased())",
                title: title,
                message: "\(title) will open a dedicated list or insight view from here.",
                detail: "Current value: \(value)",
                systemImage: title == "Plays" ? "chart.xyaxis.line" : "person.2.fill"
            )
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var editableUsername: String {
        let fallback = appState.session.username.isEmpty ? "tray3beats" : appState.session.username
        return storedUsername.isEmpty ? fallback : storedUsername
    }

    private var editableDisplayName: String {
        editableUsername
    }

    private var editableHandle: String {
        "@\(editableUsername)"
    }

    private var storedAvatarImage: UIImage? {
        guard !storedAvatarData.isEmpty else { return nil }
        return UIImage(data: storedAvatarData)
    }

    private var storedBannerImage: UIImage? {
        guard !storedBannerData.isEmpty else { return nil }
        return UIImage(data: storedBannerData)
    }
}

private struct ProfileBeatPost: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageName: String?
    let result: BeatResultModel
}

private struct ProfileBeatPostCard: View {
    let post: ProfileBeatPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            background
                .frame(maxWidth: .infinity)
                .frame(height: 228)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            Text(post.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Text(post.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let imageName = post.imageName, !imageName.isEmpty {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.94))
        }
    }
}

private struct EditStudioProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    let authStore: AuthStore
    let currentUsername: String
    let currentAvatarURL: URL?
    let currentAvatarData: Data?
    let currentBannerData: Data?
    let onSave: (String, Data?, Data?) -> Void

    @State private var draftUsername: String
    @State private var pickedAvatarItem: PhotosPickerItem?
    @State private var pickedBannerItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
    @State private var pendingBannerImage: UIImage?
    @State private var isSaving = false
    @State private var errorText: String?

    init(
        authStore: AuthStore,
        currentUsername: String,
        currentAvatarURL: URL?,
        currentAvatarData: Data?,
        currentBannerData: Data?,
        onSave: @escaping (String, Data?, Data?) -> Void
    ) {
        self.authStore = authStore
        self.currentUsername = currentUsername
        self.currentAvatarURL = currentAvatarURL
        self.currentAvatarData = currentAvatarData
        self.currentBannerData = currentBannerData
        self.onSave = onSave
        _draftUsername = State(initialValue: currentUsername)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Edit Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    bannerPreview

                    HStack(spacing: 16) {
                        avatarPreview

                        VStack(alignment: .leading, spacing: 10) {
                            photoPickerButton(title: "Change Photo", selection: $pickedAvatarItem)
                            photoPickerButton(title: "Change Banner", selection: $pickedBannerItem)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))

                        TextField("Username", text: $draftUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.88))
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        PrimaryButton(title: "Cancel", kind: .dark) {
                            dismiss()
                        }

                        PrimaryButton(title: isSaving ? "Saving..." : "Save") {
                            saveChanges()
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(20)
            }
        }
        .onChange(of: pickedAvatarItem) { _, item in
            guard let item else { return }
            loadImage(from: item) { image in
                pendingAvatarImage = image
            }
        }
        .onChange(of: pickedBannerItem) { _, item in
            guard let item else { return }
            loadImage(from: item) { image in
                pendingBannerImage = image
            }
        }
    }

    private func photoPickerButton(title: String, selection: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: selection, matching: .images) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BeatColors.accentBlueText)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(BeatColors.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(BeatPressableButtonStyle())
        .simultaneousGesture(
            TapGesture().onEnded {
                BeatHaptics.tap()
            }
        )
    }

    @ViewBuilder
    private var bannerPreview: some View {
        Group {
            if let pendingBannerImage {
                Image(uiImage: pendingBannerImage)
                    .resizable()
                    .scaledToFill()
            } else if let currentBannerData, let currentBannerImage = UIImage(data: currentBannerData) {
                Image(uiImage: currentBannerImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        BeatColors.subscriptionDeepNavy,
                        BeatColors.surfaceSecondary,
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let pendingAvatarImage {
            Image(uiImage: pendingAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
        } else if let currentAvatarData, let currentAvatarImage = UIImage(data: currentAvatarData) {
            Image(uiImage: currentAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
        } else if let currentAvatarURL {
            AsyncImage(url: currentAvatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.white.opacity(0.08)
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                )
        }
    }

    private func saveChanges() {
        let cleaned = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            errorText = "Username cannot be empty."
            return
        }

        errorText = nil
        isSaving = true
        onSave(
            cleaned,
            pendingAvatarImage?.jpegData(compressionQuality: 0.92) ?? currentAvatarData,
            pendingBannerImage?.jpegData(compressionQuality: 0.92) ?? currentBannerData
        )

        Task { @MainActor in
            if cleaned != currentUsername {
                try? await authStore.updateUsername(cleaned)
            }
            if let pendingAvatarImage {
                try? await authStore.uploadAvatar(image: pendingAvatarImage)
            }
            isSaving = false
            dismiss()
        }
    }

    private func loadImage(from item: PhotosPickerItem, completion: @escaping (UIImage) -> Void) {
        Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                completion(image)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

struct UserProfileView: View {
    let user: ProfileUser
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var messagingStore: MessagingStore
    @State private var activePlaceholder: PlaceholderDestination?
    @State private var isInboxPresented = false
    @State private var isMessageThreadPresented = false
    @State private var selectedBeat: BeatResultModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    LiquidGlassCard(cornerRadius: 28, contentPadding: 18, fillOpacity: 0.07) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Creator")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)

                            Text(user.genre)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            HStack(spacing: 12) {
                                stat(title: "Followers", value: "\(user.followers)")
                                stat(title: "Following", value: "\(user.following)")
                                stat(title: "Beats", value: "\(user.beats.count)")
                            }
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .onTapGesture {
                        BeatHaptics.tap()
                        activePlaceholder = PlaceholderDestination(
                            id: "user.creator.\(user.id.uuidString)",
                            title: "Creator Overview",
                            message: "Creator summary, analytics, and follow state will open from this overview card.",
                            detail: user.genre,
                            systemImage: "waveform.path.ecg.rectangle"
                        )
                    }

                    if !user.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(user.tags, id: \.self) { tag in
                                    Button {
                                        BeatHaptics.tap()
                                        activePlaceholder = PlaceholderDestination(
                                            id: "user.tag.\(tag)",
                                            title: tag,
                                            message: "Tag-based creator filtering and discovery will open from this pill.",
                                            systemImage: "tag.fill"
                                        )
                                    } label: {
                                        Text(tag)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.85))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(BeatPressableButtonStyle())
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Beats")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        ForEach(user.beats) { beat in
                            Button {
                                BeatHaptics.tap()
                                selectedBeat = beat.asBeatResultModel(for: user)
                            } label: {
                                LiquidGlassCard(cornerRadius: 24, contentPadding: 16, fillOpacity: 0.06) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(beat.title)
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundStyle(.white)

                                            Text("\(beat.genre) · \(beat.bpm) BPM")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.62))
                                        }

                                        Spacer()

                                        Text(beat.price)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(BeatPressableButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activePlaceholder) { destination in
            PlaceholderDetailView(destination: destination)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isMessageThreadPresented) {
            DirectMessageThreadView(user: user)
                .preferredColorScheme(.dark)
                .environmentObject(messagingStore)
        }
        .fullScreenCover(isPresented: $isInboxPresented) {
            NavigationStack {
                DirectMessageInboxView()
                    .environmentObject(messagingStore)
            }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $selectedBeat) { beat in
            UploadResultView(model: beat, sourceContext: .explore)
                .preferredColorScheme(.dark)
        }
    }

    private var headerCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 180)
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 14) {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(user.name.prefix(1).uppercased())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)

                        Text("@\(user.handle)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    BeatHaptics.tap()
                    if isViewingOwnProfile {
                        isInboxPresented = true
                    } else {
                        isMessageThreadPresented = true
                    }
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(BeatPressableButtonStyle())
                .accessibilityIdentifier("userProfile.messageButton")
                .padding(18)
            }
    }

    private var isViewingOwnProfile: Bool {
        let currentHandle = appState.session.username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return !currentHandle.isEmpty && user.handle.lowercased() == currentHandle
    }

    private func stat(title: String, value: String) -> some View {
        Button {
            BeatHaptics.tap()
            activePlaceholder = PlaceholderDestination(
                id: "user.stat.\(title.lowercased())",
                title: title,
                message: "This creator metric will open a detailed breakdown view.",
                detail: "Current value: \(value)",
                systemImage: "chart.bar.fill"
            )
        } label: {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BeatPressableButtonStyle())
    }
}

private extension FeedBeat {
    func asBeatResultModel(for user: ProfileUser) -> BeatResultModel {
        BeatResultModel(
            id: id.uuidString,
            title: title,
            artist: artist.isEmpty ? user.name : artist,
            bpm: bpm,
            genre: genre,
            releaseDate: Date(),
            artworkName: artworkName,
            youtubeVideoID: nil,
            youtubeWatchURLString: nil
        )
    }
}

struct DirectMessageEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let senderID: String
    let text: String
    let sentAt: Date

    init(
        id: UUID = UUID(),
        senderID: String,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.senderID = senderID
        self.text = text
        self.sentAt = sentAt
    }
}

struct DirectMessageThread: Identifiable, Codable, Hashable {
    let id: String
    let userID: String
    var username: String
    var handle: String
    var avatarName: String?
    var lastSeenText: String
    var messages: [DirectMessageEntry]
    var updatedAt: Date

    var lastMessagePreview: String {
        messages.last?.text ?? ""
    }
}

@MainActor
final class MessagingStore: ObservableObject {
    @Published private(set) var threads: [String: DirectMessageThread] = [:]

    private let defaultsKey = "beatfinder.direct_messages.v1"
    private let currentUserID = "current-user"

    init() {
        load()
    }

    func thread(for user: ProfileUser) -> DirectMessageThread {
        let key = user.id.uuidString

        if let existing = threads[key] {
            return existing
        }

        let thread = DirectMessageThread(
            id: key,
            userID: key,
            username: user.name,
            handle: user.handle,
            avatarName: user.avatarName,
            lastSeenText: "Last seen recently",
            messages: [],
            updatedAt: Date()
        )

        threads[key] = thread
        persist()
        return thread
    }

    func sendMessage(_ text: String, to user: ProfileUser) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var thread = thread(for: user)
        thread.username = user.name
        thread.handle = user.handle
        thread.avatarName = user.avatarName
        thread.updatedAt = Date()
        thread.messages.append(
            DirectMessageEntry(
                senderID: currentUserID,
                text: trimmed
            )
        )

        threads[thread.id] = thread
        persist()
    }

    func messageGroups(for user: ProfileUser) -> [DirectMessageEntry] {
        thread(for: user).messages
    }

    var sortedThreads: [DirectMessageThread] {
        threads.values.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    func isCurrentUserMessage(_ message: DirectMessageEntry) -> Bool {
        message.senderID == currentUserID
    }

    func profileUser(for thread: DirectMessageThread) -> ProfileUser {
        ProfileUser(
            id: UUID(uuidString: thread.userID) ?? ProfileUser.stableID(for: thread.handle),
            name: thread.username,
            handle: thread.handle,
            genre: "Creator",
            avatarName: thread.avatarName,
            tags: [],
            followers: 0,
            following: 0,
            beats: []
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: DirectMessageThread].self, from: data) else { return }
        threads = decoded
    }
}

struct DirectMessageInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messagingStore: MessagingStore
    @State private var selectedUser: ProfileUser?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if messagingStore.sortedThreads.isEmpty {
                    emptyState
                } else {
                    threadList
                }
            }
        }
        .fullScreenCover(item: $selectedUser) { user in
            DirectMessageThreadView(user: user)
                .preferredColorScheme(.dark)
                .environmentObject(messagingStore)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                BeatHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Messages")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Your recent conversations")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, BeatLayout.screenHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(BeatColors.surfaceSecondary)
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                )

            Text("No conversations yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Start a conversation from a creator profile and it will appear here.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Button {
                BeatHaptics.tap()
                dismiss()
            } label: {
                Text("Start from creator profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(BeatColors.accentBlue)
                    .clipShape(Capsule())
            }
            .buttonStyle(BeatPressableButtonStyle())

            Spacer()
        }
        .padding(.horizontal, BeatLayout.screenHorizontal)
    }

    private var threadList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(messagingStore.sortedThreads) { thread in
                    let user = messagingStore.profileUser(for: thread)

                    Button {
                        BeatHaptics.tap()
                        selectedUser = user
                    } label: {
                        HStack(spacing: 14) {
                            avatar(for: thread)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(thread.username)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Text(thread.updatedAt.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(BeatColors.textTertiary)
                                }

                                Text("@\(thread.handle)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(BeatColors.textSecondary)

                                Text(thread.lastMessagePreview.isEmpty ? "No messages yet" : thread.lastMessagePreview)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(thread.lastMessagePreview.isEmpty ? BeatColors.textTertiary : .white.opacity(0.78))
                                    .lineLimit(2)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(BeatColors.textTertiary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(BeatColors.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(BeatPressableButtonStyle())
                }
            }
            .padding(.horizontal, BeatLayout.screenHorizontal)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
    }

    private func avatar(for thread: DirectMessageThread) -> some View {
        Group {
            if let avatarName = thread.avatarName, !avatarName.isEmpty {
                Image(avatarName)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(BeatColors.surfacePrimary)
                    .overlay(
                        Text(thread.username.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct DirectMessageThreadView: View {
    let user: ProfileUser

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messagingStore: MessagingStore
    @State private var draftMessage = ""
    @FocusState private var isComposerFocused: Bool

    private var thread: DirectMessageThread {
        messagingStore.thread(for: user)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if thread.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
                .background(Color.black.opacity(0.96))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                BeatHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())
            .accessibilityIdentifier("messages.backButton")

            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(thread.lastSeenText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            Spacer()

            Button {
                BeatHaptics.tap()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())
        }
        .padding(.horizontal, BeatLayout.screenHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var avatar: some View {
        Group {
            if let avatarName = user.avatarName, !avatarName.isEmpty {
                Image(avatarName)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(BeatColors.surfaceSecondary)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(BeatColors.surfaceSecondary)
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                )

            Text("Start the conversation")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Send \(user.name) your first message about beats, collabs, or feedback.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BeatLayout.screenHorizontal)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(thread.messages) { message in
                        HStack {
                            if messagingStore.isCurrentUserMessage(message) {
                                Spacer(minLength: 52)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.text)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(
                                                messagingStore.isCurrentUserMessage(message)
                                                    ? BeatColors.accentBlue.opacity(0.32)
                                                    : BeatColors.surfaceSecondary
                                            )
                                    )

                                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(BeatColors.textTertiary)
                                    .padding(.horizontal, 4)
                            }

                            if !messagingStore.isCurrentUserMessage(message) {
                                Spacer(minLength: 52)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .onAppear {
                if let lastMessage = thread.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .onChange(of: thread.messages.count) { _, _ in
                if let lastMessage = thread.messages.last {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Write a message…", text: $draftMessage, axis: .vertical)
                .focused($isComposerFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BeatColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .accessibilityIdentifier("messages.composer")

            Button {
                BeatHaptics.tap()
                messagingStore.sendMessage(draftMessage, to: user)
                draftMessage = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? BeatColors.textTertiary : Color.black)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(
                                draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? BeatColors.surfaceSecondary
                                    : BeatColors.accentBlue
                            )
                    )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("messages.sendButton")
        }
        .padding(.horizontal, BeatLayout.screenHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }
}
