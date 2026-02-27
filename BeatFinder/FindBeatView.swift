import SwiftUI
import AVFoundation



struct FindBeatView: View {

    @Environment(\.selectedTheme) var selectedTheme
    @EnvironmentObject private var settings: SettingsStore

    @State private var beatLink: String = ""

    @State private var showUploadSheet = false

    @State private var selectedFile: URL?

    @State private var isSearching = false

    @State private var foundBeats: [BeatResult] = []
    @State private var comingSoonMessage: String?



    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let horizontalPadding: CGFloat = proxy.size.width < 360 ? 14 : 18
                let actionHorizontalPadding: CGFloat = proxy.size.width < 360 ? 16 : 28

                ZStack {
                    ThemeManager.backgroundGradient(for: selectedTheme)
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            Text("Find the Perfect Beat")
                                .font(.largeTitle.bold())
                                .foregroundColor(Color.primary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)

                            Text("Paste a link or upload your beat idea to find matching instrumentals across the web.")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)

                            TextField("Paste YouTube, Spotify, or SoundCloud link...", text: $beatLink)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(Color.primary)
                                .padding(.horizontal, horizontalPadding)

                            Button {
                                showUploadSheet = true
                            } label: {
                                Label("Upload Beat File", systemImage: "square.and.arrow.up")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.secondary.opacity(0.1))
                                    .foregroundColor(Color.primary)
                                    .cornerRadius(12)
                                    .padding(.horizontal, actionHorizontalPadding)
                            }

                            Button(action: analyzeBeat) {
                                if isSearching {
                                    ProgressView("Analyzing beat...")
                                        .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.accentColor(for: selectedTheme)))
                                        .foregroundColor(Color.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(12)
                                } else {
                                    Text("Find Similar Beats")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(ThemeManager.accentColor(for: selectedTheme))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, actionHorizontalPadding)

                            if !foundBeats.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Recommended Type Beats")
                                        .font(.headline)
                                        .foregroundColor(Color.primary)
                                        .padding(.horizontal, horizontalPadding)

                                    LazyVStack(spacing: 10) {
                                        ForEach(foundBeats) { beat in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(beat.title)
                                                        .font(.headline)
                                                        .foregroundColor(Color.primary)
                                                        .multilineTextAlignment(.leading)
                                                    Text("\(beat.producer) • \(beat.price)")
                                                        .foregroundColor(Color.secondary)
                                                }

                                                Spacer()

                                                Button {
                                                    comingSoonMessage = "Beat checkout is coming soon."
                                                } label: {
                                                    Image(systemName: "cart")
                                                        .foregroundColor(ThemeManager.accentColor(for: selectedTheme))
                                                        .frame(width: BeatLayout.iconButtonSize, height: BeatLayout.iconButtonSize)
                                                        .background(Color.secondary.opacity(0.1))
                                                        .clipShape(Circle())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding()
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(10)
                                            .padding(.horizontal, horizontalPadding)
                                        }
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, max(24, proxy.safeAreaInsets.bottom) + 24)
                    }
                }
            }
            .navigationTitle("Find Beat")
            .toolbarColorScheme(settings.toolbarColorScheme, for: .navigationBar)
            .toolbarBackground(ThemeManager.backgroundGradient(for: selectedTheme), for: .navigationBar)
            .fileImporter(isPresented: $showUploadSheet, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    selectedFile = url
                case .failure(let error):
                    print("File import failed: \(error.localizedDescription)")
                }
            }
            .alert("Coming soon", isPresented: Binding(
                get: { comingSoonMessage != nil },
                set: { if !$0 { comingSoonMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(comingSoonMessage ?? "This feature is coming soon.")
            }
            .preferredColorScheme(settings.preferredColorScheme)
        }
    }



    // MARK: - Mock Beat Finder AI (demo mode)

    func analyzeBeat() {

        isSearching = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {

            // Simulated AI beat-matching results

            foundBeats = [

                BeatResult(title: "Drake Type Beat – Skyline", producer: "WaveGod", price: "$29.99"),

                BeatResult(title: "Travis Scott Type Beat – AstroVibe", producer: "NovaSounds", price: "$24.99"),

                BeatResult(title: "Lil Baby Type Beat – Fast Lane", producer: "808King", price: "$19.99"),

                BeatResult(title: "Future Type Beat – Metro Space", producer: "ToneCraft", price: "$21.50")

            ]

            isSearching = false

        }

    }

}



struct BeatResult: Identifiable {

    let id = UUID()

    var title: String

    var producer: String

    var price: String

}
