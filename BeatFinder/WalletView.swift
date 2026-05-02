import SwiftUI

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TiltCardView {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.22, green: 0.42, blue: 0.72),
                                            Color(red: 0.10, green: 0.16, blue: 0.28)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("BeatFinder Wallet")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Spacer()
                                    Image(systemName: "wave.3.right.circle.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }

                                Spacer()

                                Text(viewModel.cardNumber)
                                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Cardholder")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.65))
                                        Text(viewModel.cardholderName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.white)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Balance")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.65))
                                        Text(viewModel.balance)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .padding(22)
                        }
                        .frame(height: 220)
                    }
                    .accessibilityIdentifier("wallet.topCard")

                    LiquidGlassCard(cornerRadius: 28, contentPadding: 18, fillOpacity: 0.07) {
                        Text("Recent Activity")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(spacing: 14) {
                            ForEach(viewModel.activity) { item in
                                HStack {
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
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(item.amount.hasPrefix("+") ? Color(red: 0.57, green: 0.88, blue: 0.67) : .white)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
    }
}
