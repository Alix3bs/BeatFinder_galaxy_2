import Foundation
import AVFoundation
import Combine

class BeatAudioEngine: ObservableObject {
    static let shared = BeatAudioEngine()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    @Published var playbackRate: Float = 1.0   // 👈 NEW
    
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        // Attach nodes
        engine.attach(playerNode)
        engine.attach(timePitch)
        
        // Connect: playerNode -> timePitch -> mainMixerNode
        engine.connect(playerNode, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
        
        // Set default rate
        timePitch.rate = 1.0
    }
    
    func loadBeat(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            duration = Double(file.length) / file.fileFormat.sampleRate
            
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error loading beat: \(error.localizedDescription)")
        }
    }
    
    func play() {
        guard let file = audioFile else { return }
        
        do {
            // Start engine if not running
            if !engine.isRunning {
                try engine.start()
            }
            
            // If already playing, do nothing
            if playerNode.isPlaying {
                return
            }
            
            // If paused, just resume playback
            // Note: AVAudioPlayerNode doesn't have a direct "isPaused" property,
            // but if engine is running and node is not playing, we can resume
            if engine.isRunning && !playerNode.isPlaying {
                // Resume playback without rescheduling
                playerNode.play()
                isPlaying = true
                startTimer()
                return
            }
            
            // Schedule and play (first time or after stop)
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.stopTimer()
                }
            }
            playerNode.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Error starting playback: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimer()
        // Note: Engine stays running so we can resume with play()
    }
    
    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func setRate(_ rate: Float) {
        timePitch.rate = rate
        DispatchQueue.main.async {
            self.playbackRate = rate
        }
    }
    
    private func startTimer() {
        stopTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Update current time (simplified - in production you'd track actual playback position)
            if self.isPlaying {
                self.currentTime += 0.1
                if self.currentTime >= self.duration {
                    self.currentTime = 0
                }
            }
        }
    }
    
    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    deinit {
        stop()
        engine.reset()
    }
}

