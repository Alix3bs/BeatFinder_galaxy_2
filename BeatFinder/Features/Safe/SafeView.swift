import SwiftUI

struct SafeView: View {
    @StateObject private var viewModel = SafeViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Safe")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Locked results and protected references.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    ForEach(viewModel.items) { item in
                        LiquidGlassCard(cornerRadius: 28, contentPadding: 18, fillOpacity: 0.07) {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(item.subtitle)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.68))

                                    Text(item.date)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.54))
                                }

                                Spacer()

                                Button {
                                    viewModel.requestDelete(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }

            if let pendingDeletion = viewModel.pendingDeletion {
                Color.black.opacity(0.56)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        viewModel.cancelDeletion()
                    }

                SafeDeleteConfirmationView(
                    itemTitle: pendingDeletion.title,
                    onCancel: viewModel.cancelDeletion,
                    onConfirm: viewModel.confirmDeletion
                )
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(MotionTokens.mediumEase, value: viewModel.pendingDeletion != nil)
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }
}
