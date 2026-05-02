import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    banner

                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Text(viewModel.displayName(from: appState.session))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)

                                if appState.session.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Color(red: 0.54, green: 0.79, blue: 1.0))
                                }
                            }

                            Text(viewModel.handle(from: appState.session))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.68))

                            Text(viewModel.bio)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.top, 2)
                        }

                        statRow

                        LiquidGlassButton(action: {
                            appState.presentSubscription()
                        }, cornerRadius: 22, fillOpacity: 0.1) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appState.subscription.accessLevel == .goPlus ? "GO+ Active" : "Unlock GO+")
                                        .font(.system(size: 17, weight: .bold))
                                    Text("Open the membership flow and manage your plan.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }

                        LiquidGlassCard(cornerRadius: 28, contentPadding: 18, fillOpacity: 0.07) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Membership")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(appState.subscription.accessLevel == .goPlus ? "Your account is already running GO+ access." : "Upgrade to keep uploads, results, and profile tools in one premium flow.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                        }
                    }
                    .padding(.horizontal, BeatLayout.screenHorizontal)
                }
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.33, blue: 0.58),
                            Color(red: 0.10, green: 0.14, blue: 0.24),
                            .black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 250)

            VStack {
                HStack(spacing: 10) {
                    Spacer()

                    Button {
                        appState.presentSubscription()
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.crownButton")

                    Button {
                        appState.openSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 12)

                Spacer()
            }

            avatar
                .offset(x: BeatLayout.screenHorizontal, y: 48)
        }
        .padding(.bottom, 48)
    }

    private var avatar: some View {
        Group {
            if let avatarURL = appState.session.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.08)
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Text(String(viewModel.displayName(from: appState.session).prefix(1)).uppercased())
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black, lineWidth: 4))
    }

    private var statRow: some View {
        HStack {
            ForEach(viewModel.stats) { stat in
                VStack(spacing: 5) {
                    Text(stat.value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Text(stat.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }
}
