import SwiftUI

struct BeatResultView: View {
    let model: BeatResultModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.tabBarClearance) private var tabBarClearance
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikeService
    @EnvironmentObject private var settings: SettingsStore

    @State private var isLiked = false
    @State private var progress: Double = 0.4
    @State private var isPlaying: Bool = true

    private var youtubeSearchURL: URL? {
        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [
            URLQueryItem(name: "search_query", value: "\(model.title) \(model.artist) type beat")
        ]
        return components?.url
    }

    var body: some View {
        ZStack {
            // Background: YouTube Thumbnail (Simulated with artwork or dark gradient)
            GeometryReader { proxy in
                ZStack {
                    if let name = model.artworkName, let ui = UIImage(named: name) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .blur(radius: 20) // Blurred thumbnail background
                    } else {
                        Color(red: 0.1, green: 0.1, blue: 0.15).ignoresSafeArea()
                    }
                    // Dark overly to make text readable
                    Color.black.opacity(0.4).ignoresSafeArea()
                }
            }
            .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer()

                // Main Player UI (Liquid Glass)
                VStack(spacing: 20) {
                    // Title & Artist
                    VStack(spacing: 6) {
                        Text(model.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("\(model.artist) • \(model.genre)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    // Progress Bar
                    VStack(spacing: 8) {
                        Slider(value: $progress, in: 0...1)
                            .tint(Color(red: 0.25, green: 0.6, blue: 1.0)) // Blue accent

                        HStack {
                            Text("1:12")
                            Spacer()
                            Text("-2:08")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 10)

                    // Controls
                    HStack(spacing: 30) {
                        Button { } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }

                        Button {
                            isPlaying.toggle()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white)
                        }

                        Button { } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                    }

                    // Bottom Row: Like & YouTube Button
                    HStack {
                        Button {
                            isLiked.toggle()
                        } label: {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 24))
                                .foregroundStyle(isLiked ? .red : .white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Button {
                            if let url = youtubeSearchURL {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                Text("Watch on YouTube")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(24)
                .liquidGlass(cornerRadius: 30, borderOpacity: 0.2) // Liquid glass styling
                .padding(.horizontal, 16)
                .padding(.bottom, tabBarClearance + 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark) // Dark mode only
    }
}
