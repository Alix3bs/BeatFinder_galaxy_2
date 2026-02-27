import SwiftUI

struct BeatFeedCardView: View {
    let beat: FeedBeat
    
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.35
    @State private var playbackRate: Double = 1.0
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var feedbackMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        
            VStack {
                Spacer(minLength: 0)
                
                HStack(alignment: .bottom) {
                    // LEFT: artwork + info + slider
                    VStack(alignment: .leading, spacing: 12) {
                        

                        // Artwork circle
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.18),
                                            Color.white.opacity(0.02)
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 120
                                    )
                                )
                                .frame(width: 220, height: 220)
                            
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                .frame(width: 240, height: 240)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.6)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundColor(.black.opacity(0.3))
                                )
                        }
                        
                        // Beat info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(beat.title)
                                .font(.system(size: 22, weight: .semibold))
                            
                            HStack(spacing: 6) {
                                Text(beat.producer)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Text("• \(beat.genre) Type Beat")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text("\(beat.plays) plays  •  \(beat.likes) likes")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Progress + controls
                        VStack(spacing: 8) {
                            Slider(value: $progress, in: 0...1)
                                .tint(.white)
                            
                            HStack {
                                Text("0:45")
                                Spacer()
                                Text("3:20")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 28) {
                                Button {
                                    progress = max(progress - 0.1, 0)
                                } label: {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                }
                                
                                Button {
                                    // Load beat when play is tapped
                                    if let beatURL = Bundle.main.url(forResource: "samplebeat", withExtension: "mp3") {
                                        BeatAudioEngine.shared.loadBeat(url: beatURL)
                                    }
                                    isPlaying.toggle()
                                    // hook play / pause
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 64, height: 64)
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                Button {
                                    progress = min(progress + 0.1, 1)
                                } label: {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                }
                            }
                            
                            // Speed control
                            HStack(spacing: 10) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                ForEach([0.5, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                    Button {
                                        playbackRate = rate
                                        BeatAudioEngine.shared.setRate(Float(rate))
                                    } label: {
                                        Text("\(rate, specifier: "%.2gx")")
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(
                                                playbackRate == rate
                                                ? Color.white
                                                : Color.white.opacity(0.08)
                                            )
                                            .foregroundColor(
                                                playbackRate == rate ? .black : .white
                                            )
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Spacer()
                    
                    // RIGHT: icons column (like TikTok)
                    VStack(spacing: 22) {
                        Button {
                            isLiked.toggle()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 24))
                                    .foregroundColor(isLiked ? .red : .white)
                                Text(beat.likes)
                                    .font(.system(size: 11))
                            }
                        }
                        
                        Button {
                            feedbackMessage = "Comments are coming soon."
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "message")
                                    .font(.system(size: 22))
                                Text("132")
                                    .font(.system(size: 11))
                            }
                        }
                        
                        Button {
                            feedbackMessage = "Sharing is coming soon."
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                                .font(.system(size: 22))
                        }
                        
                        Button {
                            isSaved.toggle()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 22))
                                Text("Save")
                                    .font(.system(size: 11))
                            }
                        }
                        
                        Button {
                            feedbackMessage = "Beat checkout is coming soon."
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bag.fill.badge.plus")
                                    .font(.system(size: 22))
                                Text(beat.price)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .alert("Coming soon", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(feedbackMessage ?? "")
        }
    }
}
