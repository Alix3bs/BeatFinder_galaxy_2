import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    LiquidGlassCard(cornerRadius: 28, contentPadding: 18, fillOpacity: 0.07) {
                        Text("Verification")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: appState.session.isVerified ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(appState.session.isVerified ? Color(red: 0.54, green: 0.79, blue: 1.0) : .white.opacity(0.76))
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.verificationTitle(for: appState.session))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(viewModel.verificationDetail(for: appState.session))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                        }
                    }

                    NavigationLink(value: ProfileRoute.wallet) {
                        LiquidGlassCard(cornerRadius: 28, contentPadding: 18, fillOpacity: 0.07) {
                            HStack(spacing: 14) {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Wallet")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text("View card balance, activity, and payouts.")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.64))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.walletRow")
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
