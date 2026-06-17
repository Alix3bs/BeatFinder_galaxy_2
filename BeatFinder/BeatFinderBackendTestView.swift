import SwiftUI

struct BeatFinderBackendTestView: View {
    @StateObject private var viewModel = BeatFinderBackendTestViewModel()

    var body: some View {
        ScreenContainer(
            spacing: 18,
            topPadding: 16,
            bottomPadding: 28,
            maxWidthStyle: .standard,
            includeTabBarClearance: true
        ) {
            Color.black
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Text("Backend API Settings")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Choose the backend URL for local simulator, LAN iPhone, or a future hosted BeatFinder API.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            backendURLSettings

            SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
                VStack(alignment: .leading, spacing: 14) {
                    backendHeader

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    field("Top beat", value: viewModel.topBeatTitle)
                    field("Confidence", value: viewModel.confidence)
                    field("Producer tag detected", value: viewModel.detectedProducerTag)
                    field("Matched producer channel", value: viewModel.matchedProducerChannel)
                    field("Producer tag confidence", value: viewModel.producerTagConfidenceText)
                    field("Discovery status", value: viewModel.discoveryStatus)
                    field("YouTube video match", value: viewModel.youtubeVideoMatchTitle)

                    if !viewModel.possibleReasons.isEmpty {
                        chipGroup(title: "Possible reasons", values: viewModel.possibleReasons)
                    }

                    if !viewModel.recommendedNextSearches.isEmpty {
                        chipGroup(title: "Recommended next searches", values: viewModel.recommendedNextSearches)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BeatColors.danger)
                    }

                    backendActionButtons
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.testBackendConnection()
        }
    }

    private var backendURLSettings: some View {
        SectionCard(cornerRadius: 22, padding: 18, fill: Color.white.opacity(0.05), strokeOpacity: 0.08) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Backend URL")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Text(viewModel.baseURLText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(viewModel.isURLValid ? BeatColors.accentBlue : BeatColors.danger)
                        .textSelection(.enabled)
                }

                VStack(spacing: 8) {
                    ForEach(BeatFinderBackendURLPreset.allCases) { preset in
                        backendPresetRow(preset)
                    }
                }

                if viewModel.selectedPreset == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom backend URL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BeatColors.textTertiary)

                        TextField("https://your-hosted-backend.example.com", text: $viewModel.customURLString)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }

                Text("Simulator can use 127.0.0.1. A physical iPhone needs your Mac LAN IP or a hosted HTTPS backend.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BeatColors.textTertiary)
            }
        }
    }

    private func backendPresetRow(_ preset: BeatFinderBackendURLPreset) -> some View {
        Button {
            BeatHaptics.tap()
            viewModel.selectPreset(preset)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.selectedPreset == preset ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(viewModel.selectedPreset == preset ? BeatColors.accentBlue : .white.opacity(0.44))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Text(preset == .custom ? preset.detail : preset.urlString)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BeatColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(viewModel.selectedPreset == preset ? BeatColors.accentBlue.opacity(0.14) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(viewModel.selectedPreset == preset ? BeatColors.accentBlue.opacity(0.32) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(BeatPressableButtonStyle())
    }

    private var backendHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.baseURLText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(viewModel.isURLValid ? BeatColors.accentBlue : BeatColors.danger)

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }

    private var backendActionButtons: some View {
        VStack(spacing: 10) {
            Button {
                BeatHaptics.tap()
                Task {
                    await viewModel.testBackendConnection()
                }
            } label: {
                backendButtonLabel(
                    title: viewModel.isLoading ? "Testing Backend..." : "Test Backend Connection",
                    systemImage: "heart.text.square"
                )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .disabled(viewModel.isLoading || !viewModel.isURLValid)

            Button {
                BeatHaptics.tap()
                Task {
                    await viewModel.runLocalSmokeTest()
                }
            } label: {
                backendButtonLabel(
                    title: viewModel.isLoading ? "Running Search..." : "Run Discovery Smoke Test",
                    systemImage: "magnifyingglass.circle"
                )
            }
            .buttonStyle(BeatPressableButtonStyle())
            .disabled(viewModel.isLoading || !viewModel.isURLValid)
        }
    }

    private func backendButtonLabel(title: String, systemImage: String) -> some View {
        HStack {
            if viewModel.isLoading {
                ProgressView()
                    .tint(BeatColors.accentBlueText)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
            }

            Text(title)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(BeatColors.accentBlueText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeatColors.accentBlue)
        )
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return "Ready to call /health and /search/text."
        case .loading:
            return "Checking configured BeatFinder backend..."
        case .success:
            return viewModel.searchResponse == nil
                ? "Backend responded to /health."
                : "Backend responded. Discovery payload decoded."
        case .failure:
            return "Backend test failed. Check the URL above and confirm the server is reachable."
        }
    }

    private func field(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BeatColors.textTertiary)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chipGroup(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BeatColors.textTertiary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
        }
    }
}
