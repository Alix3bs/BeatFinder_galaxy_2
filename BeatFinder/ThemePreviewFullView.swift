import SwiftUI
import CoreMotion
import AVFoundation
import ReplayKit

struct ThemePreviewFullView: View {
    var selectedBeat: Beat? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var settings: SettingsStore
    @State private var waveformValues: [CGFloat] = Array(repeating: 0.3, count: 20)
    @State private var isAnimating = false
    @State private var playIconScale: CGFloat = 1.0
    @State private var playIconGlow: Double = 0.4
    @State private var ringPulse: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.4
    @State private var motionManager = CMMotionManager()
    @State private var pitch: Double = 0.0
    @State private var roll: Double = 0.0
    @State private var isCDSpinning: Bool = true
    @State private var cdRotation: Double = 0
    @State private var isPlaying: Bool = false
    @State private var audioEngine = AVAudioEngine()
    @State private var playerNode = AVAudioPlayerNode()
    @State private var amplitude: Float = 0.0
    @State private var isRecording = false
    @State private var recorder = RPScreenRecorder.shared()
    @State private var quickActionMessage: String?
    @State private var didSaveBeat = false

    var body: some View {
        ZStack {
            ThemeManager.backgroundGradient(for: settings.selectedTheme)
                .ignoresSafeArea()
            
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
                Spacer()
            }
            .zIndex(1000)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "music.note")
                        .font(.title3)
                    Spacer()
                    Text("BeatFinder Live Preview")
                        .font(.headline)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .foregroundColor(.white)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    ThemeManager.accentColor(for: settings.selectedTheme)
                                        .opacity(0.9 + 0.1 * playIconGlow)
                                )
                                .frame(height: 140)
                                .overlay(
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("🎧 Drake Type Beat")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("Energy Flow – 140 BPM")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            // ZStack with glow ring + play icon
                                            ZStack {
                                                Circle()
                                                    .stroke(
                                                        AngularGradient(
                                                            gradient: Gradient(colors: [
                                                                ThemeManager.accentColor(for: settings.selectedTheme),
                                                                .white.opacity(0.6),
                                                                ThemeManager.accentColor(for: settings.selectedTheme)
                                                            ]),
                                                            center: .center
                                                        )
                                                        .opacity(ringOpacity),
                                                        lineWidth: 6
                                                    )
                                                    .frame(width: 80 * ringPulse, height: 80 * ringPulse)
                                                    .blur(radius: 12)
                                                    .scaleEffect(playIconScale)
                                                
                                                ZStack {
                                                    // CD Outer Edge
                                                    Circle()
                                                        .fill(
                                                            RadialGradient(
                                                                gradient: Gradient(colors: [
                                                                    .white,
                                                                    ThemeManager.accentColor(for: settings.selectedTheme).opacity(0.8),
                                                                    .black.opacity(0.7)
                                                                ]),
                                                                center: .center,
                                                                startRadius: 2,
                                                                endRadius: 50
                                                            )
                                                        )
                                                        .overlay(
                                                            Circle()
                                                                .stroke(
                                                                    LinearGradient(
                                                                        colors: [
                                                                            .white.opacity(0.6),
                                                                            ThemeManager.accentColor(for: settings.selectedTheme),
                                                                            .white.opacity(0.6)
                                                                        ],
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        )
                                                        .rotationEffect(.degrees(cdRotation))
                                                        .frame(width: 80, height: 80)
                                                        .scaleEffect(playIconScale)
                                                        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: cdRotation)
                                                        .shadow(color: ThemeManager.accentColor(for: settings.selectedTheme).opacity(0.6), radius: 12)
                                                    
                                                    // CD Center Reflection
                                                    Circle()
                                                        .fill(
                                                            RadialGradient(
                                                                gradient: Gradient(colors: [
                                                                    ThemeManager.accentColor(for: settings.selectedTheme),
                                                                    .white.opacity(0.6),
                                                                    .black.opacity(0.7)
                                                                ]),
                                                                center: .center,
                                                                startRadius: 1,
                                                                endRadius: 20
                                                            )
                                                        )
                                                        .frame(width: 20, height: 20)
                                                    
                                                    // Play Triangle in the Center
                                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                                        .foregroundColor(.white)
                                                        .font(.system(size: 22, weight: .bold))
                                                        .scaleEffect(isPlaying ? 0.9 : 1.0)
                                                        .opacity(isPlaying ? 0.7 : 1.0)
                                                        .animation(.easeInOut(duration: 0.2), value: isPlaying)
                                                }
                                                .onTapGesture {
                                                    togglePlayback()
                                                    triggerImpact(.medium)
                                                }
                                            }
                                            .parallaxEffect(pitch: pitch, roll: roll, magnitude: 12)
                                        }
                                    }
                                    .padding()
                                )
                                .overlay(
                                    VStack {
                                        Spacer()
                                        AnimatedWaveform(
                                            color: .white.opacity(0.9),
                                            values: $waveformValues
                                        )
                                        .padding(.bottom, 14)
                                    }
                                )
                                .shadow(radius: 6)
                        }
                        .parallaxEffect(pitch: pitch, roll: roll, magnitude: 6)

                        HStack(spacing: 16) {
                            ForEach(["❤️ Save", "⚡ Remix", "💬 Share"], id: \.self) { action in
                                Button {
                                    handleQuickAction(action)
                                } label: {
                                    Text(action)
                                        .fontWeight(.semibold)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 18)
                                        .background(ThemeManager.accentColor(for: settings.selectedTheme).opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("🔥 Trending Beats")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(1..<4) { index in
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 60)
                                    .overlay(
                                        HStack {
                                            Image(systemName: "waveform")
                                                .foregroundColor(ThemeManager.accentColor(for: settings.selectedTheme))
                                            Text("Producer \(index) – Type Beat #\(index)")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "play.fill")
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding(.horizontal)
                                    )
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }

                HStack {
                    Spacer()
                    Image(systemName: "house.fill")
                        .foregroundColor(ThemeManager.accentColor(for: settings.selectedTheme))
                    Spacer()
                    Image(systemName: "music.note.list")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "message")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // MARK: - Recording Button Overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        toggleRecording()
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(isRecording ? .red : .white)
                            .shadow(radius: 10)
                            .padding()
                    }
                }
            }
        }
        .preferredColorScheme(settings.preferredColorScheme)
        .animation(.easeInOut(duration: 0.4), value: settings.selectedTheme)
        .alert("BeatFinder", isPresented: Binding(
            get: { quickActionMessage != nil },
            set: { if !$0 { quickActionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(quickActionMessage ?? "")
        }
        .onAppear {
            isPlaying = settings.autoplayPreviews
            if settings.autoplayPreviews {
                isAnimating = true
                startWaveformAnimation()
                startMotionUpdates()
                startCDSpin()
                startAudioPlayback()
            }
        }
        .onDisappear {
            isAnimating = false
            isPlaying = false
            playerNode.stop()
            audioEngine.stop()
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            motionManager.stopDeviceMotionUpdates()
        }
    }
}

struct AnimatedWaveform: View {
    var color: Color
    @Binding var values: [CGFloat]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(values.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: 40 * values[index])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: values)
    }
}

extension View {
    func parallaxEffect(pitch: Double, roll: Double, magnitude: CGFloat = 20) -> some View {
        let x = CGFloat(roll) * magnitude
        let y = CGFloat(pitch) * magnitude
        return self.offset(x: x, y: y)
            .rotation3DEffect(.degrees(roll * 10), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(pitch * 10), axis: (x: 1, y: 0, z: 0))
    }
}

extension ThemePreviewFullView {
    func startWaveformAnimation() {
        DispatchQueue.global(qos: .background).async {
            while isAnimating {
                DispatchQueue.main.async {
                    // Scale waveform bars by live amplitude
                    for i in waveformValues.indices {
                        let randomness = CGFloat.random(in: 0.7...1.3)
                        waveformValues[i] = max(0.2, CGFloat(amplitude) * 20 * randomness)
                    }
                    
                    // Glow & pulse from amplitude
                    let normalizedAmp = min(max(amplitude * 10, 0.1), 1.0)
                    withAnimation(.easeInOut(duration: 0.1)) {
                        playIconScale = CGFloat(1.0 + normalizedAmp * 0.1)
                        playIconGlow = Double(0.4 + normalizedAmp * 0.6)
                        ringPulse = CGFloat(1.0 + normalizedAmp * 0.4)
                        ringOpacity = 0.4 + Double(normalizedAmp * 0.5)
                    }
                    
                    // Slight spin bump from bass hits
                    cdRotation += Double(normalizedAmp * 8)
                }
                usleep(50_000) // 20 FPS for smoothness
            }
        }
    }
    
    func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { data, _ in
                if let motion = data {
                    pitch = motion.attitude.pitch
                    roll = motion.attitude.roll
                }
            }
        }
    }
    
    func startCDSpin() {
        guard isPlaying else { return }
        withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
            cdRotation += 360
        }
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            startAudioPlayback() // 🔊 Play beat
            isAnimating = true
            startWaveformAnimation()
            startMotionUpdates()
            startCDSpin()
        } else {
            playerNode.stop()
            audioEngine.stop()
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            isAnimating = false
            motionManager.stopDeviceMotionUpdates()
            
            // Smoothly slow down the CD spin
            withAnimation(.easeOut(duration: 1.5)) {
                cdRotation += 180
            }
            
            // Slightly dim the glow and ring
            withAnimation(.easeOut(duration: 0.5)) {
                playIconGlow = 0.2
                ringOpacity = 0.2
            }
        }
    }
    
    func startAudioPlayback() {
        let url: URL
        
        if let beat = selectedBeat {
            // Look for a beat file in your Bundle or Documents folder
            if let localURL = Bundle.main.url(forResource: beat.title, withExtension: "mp3") {
                url = localURL
            } else if let uploadedPath = UserDefaults.standard.string(forKey: "uploadedBeatURL"),
                      FileManager.default.fileExists(atPath: uploadedPath) {
                url = URL(fileURLWithPath: uploadedPath)
            } else {
                print("No beat found for \(beat.title)")
                return
            }
        } else {
            // Default fallback beat
            if let userBeatPath = UserDefaults.standard.string(forKey: "uploadedBeatURL"),
               FileManager.default.fileExists(atPath: userBeatPath) {
                url = URL(fileURLWithPath: userBeatPath)
            } else {
                guard let defaultURL = Bundle.main.url(forResource: "samplebeat", withExtension: "mp3") else {
                    print("Beat file not found")
                    return
                }
                url = defaultURL
            }
        }
        
        // Reset engine if needed
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }
        
        let file = try! AVAudioFile(forReading: url)
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: file.processingFormat)
        
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: file.processingFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            var sumOfSquares: Float = 0
            for i in 0..<frameLength {
                let sample = channelData.pointee[i]
                sumOfSquares += sample * sample
            }
            let meanSquare = sumOfSquares / Float(frameLength)
            let rms = sqrt(meanSquare)
            DispatchQueue.main.async {
                amplitude = rms
            }
        }
        
        try! audioEngine.start()
        let isPlayingRef = isPlaying
        playerNode.scheduleFile(file, at: nil) {
            // Loop playback when file ends
            DispatchQueue.main.async {
                if isPlayingRef {
                    playerNode.scheduleFile(file, at: nil)
                    playerNode.play()
                }
            }
        }
        playerNode.play()
    }
    
    func toggleRecording() {
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func startRecording() {
        recorder.isMicrophoneEnabled = true
        recorder.startRecording { error in
            if let error = error {
                print("Recording failed to start: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    withAnimation {
                        isRecording = true
                    }
                    triggerImpact(.medium)
                    print("🎥 Recording started")
                }
            }
        }
    }
    
    func stopRecording() {
        recorder.stopRecording { previewVC, error in
            DispatchQueue.main.async {
                withAnimation {
                    isRecording = false
                }
                triggerImpact(.light)
            }
            
            if let error = error {
                print("❌ Recording error: \(error.localizedDescription)")
                return
            }
            
            if let previewVC = previewVC {
                DispatchQueue.main.async {
                    previewVC.modalPresentationStyle = .fullScreen
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(previewVC, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    func handleQuickAction(_ action: String) {
        switch action {
        case "❤️ Save":
            didSaveBeat.toggle()
            quickActionMessage = didSaveBeat ? "Saved to your collection." : "Removed from your collection."
        case "⚡ Remix":
            quickActionMessage = "Remix tools are coming soon."
        case "💬 Share":
            quickActionMessage = "Sharing is coming soon."
        default:
            quickActionMessage = "This action is coming soon."
        }
    }

    func triggerImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
