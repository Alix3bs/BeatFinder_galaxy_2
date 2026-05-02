import SwiftUI

struct UploadResultView: View {
    let model: BeatResultModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: UploadResultViewModel

    init(model: BeatResultModel) {
        self.model = model
        _viewModel = StateObject(wrappedValue: UploadResultViewModel(model: model))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    YouTubePreviewPlayerView(
                        videoID: viewModel.previewVideoID,
                        title: "\(model.title) by \(model.artist)"
                    )

                    LiquidGlassCard(cornerRadius: 30, contentPadding: 20, fillOpacity: 0.07) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(model.artist)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            HStack(spacing: 10) {
                                metadataPill(title: model.genre)
                                metadataPill(title: "\(model.bpm) BPM")
                                metadataPill(title: viewModel.releaseDateText)
                            }

                            Text("Embedded preview stays in-app, but the full watch action still routes to YouTube as required.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))

                            LiquidGlassButton(action: openWatchURL, cornerRadius: 18, fillOpacity: 0.12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle.fill")
                                    Text("Watch on YouTube")
                                        .font(.system(size: 15, weight: .bold))
                                }
                            }
                            .accessibilityIdentifier("uploadResult.watchOnYouTube")
                        }
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func metadataPill(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func openWatchURL() {
        guard let watchURL = viewModel.watchURL else { return }
        openURL(watchURL)
    }
}
