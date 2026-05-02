import SwiftUI

struct UploadView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = UploadViewModel()

    var body: some View {
        ZStack {
            StarDotBackground().ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Upload")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                    }

                    Text(viewModel.statusLine)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                OrbitingIconField(state: viewModel.orbitState)
                    .frame(height: 340)

                Spacer(minLength: 0)

                LiquidGlassCard(cornerRadius: 30, contentPadding: 20, fillOpacity: 0.08) {
                    VStack(spacing: 14) {
                        Text(viewModel.headline)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text(viewModel.caption)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                            .multilineTextAlignment(.center)

                        primaryButton

                        if viewModel.showsResetAction {
                            Button {
                                viewModel.reset()
                            } label: {
                                Text("Analyze Another")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, BeatLayout.screenHorizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var primaryButton: some View {
        LiquidGlassButton(action: handlePrimaryAction, cornerRadius: 20, fillOpacity: 0.12) {
            Text(viewModel.primaryActionTitle)
                .font(.system(size: 16, weight: .bold))
        }
        .disabled(viewModel.state == .analyzing)
        .opacity(viewModel.state == .analyzing ? 0.7 : 1)
        .accessibilityIdentifier("upload.primaryButton")
    }

    private func handlePrimaryAction() {
        if let result = viewModel.matchedResult {
            appState.openUploadResult(result)
        } else {
            viewModel.startAnalysis()
        }
    }
}
