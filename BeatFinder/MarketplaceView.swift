import SwiftUI
import AVFoundation
import Combine

class AudioPlayerManager: NSObject, AVAudioPlayerDelegate, ObservableObject {
    @Published var currentlyPlaying: UUID?
    private var player: AVAudioPlayer?

    func togglePlay(for beat: Beat) {
        if currentlyPlaying == beat.id {
            player?.stop()
            currentlyPlaying = nil
            return
        }
        // Stop any existing playback before starting a new one
        player?.stop()
        guard let url = Bundle.main.url(forResource: "samplebeat", withExtension: "mp3") else { return }
        do {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            currentlyPlaying = beat.id
            UserDefaults.standard.set(beat.title, forKey: "currentBeatTitle")
        } catch {
            print("Error playing beat: \(error.localizedDescription)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentlyPlaying = nil
    }
}

struct MarketplaceView: View {
    @State private var beats: [Beat] = [
        Beat(title: "Neon Drip", artistName: "Prod. Jvstin", genre: "Trap", price: "$25", plays: "45.2K", likes: "3.1K", imageName: "beat1", isVerified: true, bpm: 145),
        Beat(title: "Midnight Flow", artistName: "Kairo", genre: "Lo-Fi", price: "$15", plays: "28.5K", likes: "2.2K", imageName: "beat2", isVerified: false, bpm: 120),
        Beat(title: "Eclipse", artistName: "Nova", genre: "Drill", price: "$30", plays: "52.1K", likes: "4.5K", imageName: "beat3", isVerified: true, bpm: 132),
        Beat(title: "Solar Bounce", artistName: "Aero", genre: "Afrobeats", price: "$20", plays: "35.8K", likes: "2.8K", imageName: "beat4", isVerified: false, bpm: 108)
    ]
    
    @State private var player: AVAudioPlayer?
    @StateObject private var audioManager = AudioPlayerManager()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text("🔥 Beat Marketplace")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        ForEach(beats, id: \.id) { beat in
                            BeatCardView(
                                beat: beat,
                                isPlaying: audioManager.currentlyPlaying == beat.id,
                                onPlayTapped: {
                                    audioManager.togglePlay(for: beat)
                                }
                            )
                        }
                    }
                    .padding(.bottom, 40)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}


struct BeatCardView: View {
    let beat: Beat
    let isPlaying: Bool
    let onPlayTapped: () -> Void
    @State private var showPurchasePopup = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.black.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
            
            HStack(spacing: 16) {
                Image(beat.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .shadow(radius: 3)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(beat.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(beat.artistName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(beat.bpm ?? 0) BPM • \(beat.genre)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                VStack(spacing: 8) {
                    Text(beat.price)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Button(action: onPlayTapped) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(isPlaying ? .green : .white)
                            .shadow(radius: 5)
                    }
                    
                    NavigationLink(destination: ThemePreviewFullView(selectedBeat: beat)) {
                        Text("Visualizer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(
                                LinearGradient(colors: [Color.blue, Color.purple],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )
                            .cornerRadius(10)
                    }
                    
                    Button(action: { showPurchasePopup = true }) {
                        Text("Buy Beat")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(
                                LinearGradient(colors: [Color.green, Color.teal],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )
                            .cornerRadius(10)
                    }
                    .sheet(isPresented: $showPurchasePopup) {
                        PurchaseView(beat: beat)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}
