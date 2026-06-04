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
                Text("Backend API Test")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Local dev probe for BeatFinder hybrid search and producer discovery enrichment.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

                    Button {
                        BeatHaptics.tap()
                        Task {
                            await viewModel.runLocalSmokeTest()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(BeatColors.accentBlueText)
                            }

                            Text(viewModel.isLoading ? "Testing Backend..." : "Run Local Backend Test")
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
                    .buttonStyle(BeatPressableButtonStyle())
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.runLocalSmokeTest()
        }
    }

    private var backendHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.baseURL.absoluteString)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(BeatColors.accentBlue)

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return "Ready to call /health and /search/text."
        case .loading:
            return "Checking local BeatFinder backend..."
        case .success:
            return "Backend responded. Discovery payload decoded."
        case .failure:
            return "Backend test failed. Confirm the local server is running."
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
