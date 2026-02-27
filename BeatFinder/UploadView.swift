import SwiftUI
import PhotosUI

struct UploadView: View {
    @Environment(\.tabBarClearance) private var tabBarClearance
    
    // Orbit Animation State
    @State private var rotationAngle: Double = 0
    @State private var isAnalyzing: Bool = false
    
    @State private var showSourceMenu = false
    @State private var goToResult = false

    let platformIcons = [
        "applelogo", "play.rectangle.fill", "music.note", "video.fill",
        "cloud.fill", "waveform", "headphones", "speaker.wave.2.fill"
    ]
    
    var body: some View {
        ZStack {
            // Background: Black + Neon Dot Grid
            Color.black.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()
            
            VStack {
                HStack {
                    Text("Upload")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
                
                // Orbiting Center UI
                ZStack {
                    // Orbit rings
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: 170, height: 170)
                    
                    // Center Icon (BeatFinder Logo / Waveform)
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.1, green: 0.2, blue: 0.4))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color(red: 0.25, green: 0.6, blue: 1.0).opacity(isAnalyzing ? 0.8 : 0.3), radius: isAnalyzing ? 30 : 10)
                        
                        Image(systemName: "waveform")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(.white)
                            .scaleEffect(isAnalyzing ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnalyzing)
                    }
                    
                    // Orbiting Icons
                    ForEach(0..<8, id: \.self) { index in
                        let angle = (Double(index) / 8.0) * .pi * 2 + rotationAngle
                        let radius: CGFloat = 125
                        
                        let x = cos(angle) * radius
                        let y = sin(angle) * radius
                        
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: platformIcons[index])
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .offset(x: x, y: y)
                        // Counter-rotate to keep icons upright
                        .rotationEffect(.radians(-rotationAngle))
                    }
                }
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = .pi * 2
                    }
                }
                
                Spacer()
                
                // Bottom CTA
                VStack(spacing: 20) {
                    Text(isAnalyzing ? "Analyzing..." : "Ready to find your sound")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Button {
                        isAnalyzing = true
                        // Simulate selecting a file and analyzing...
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotationAngle += .pi * 4 // Spin faster
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            goToResult = true
                            isAnalyzing = false
                        }
                    } label: {
                        Text("Select Beat")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, tabBarClearance + 20)
            }
        }
        .navigationDestination(isPresented: $goToResult) {
            BeatResultView(model: BeatResultModel(id: UUID().uuidString, title: "New Find", artist: "Unknown", bpm: 120, genre: "Hip Hop", releaseDate: Date(), artworkName: "nest_music"))
        }
    }
}

#Preview {
    UploadView()
}
