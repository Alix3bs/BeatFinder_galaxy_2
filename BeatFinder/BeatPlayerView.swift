//
//  BeatPlayerView.swift
//  BeatFinder
//

import SwiftUI

struct BeatPlayerView: View {
    // MARK: - Input props (from your Beat model / caller)
    let title: String          // e.g. "Midnight Dreams"
    let producerName: String   // e.g. "LunarBeats"
    let subtitle: String       // e.g. "HipHop Type Beat"
    let statsLine: String      // e.g. "31.5K plays • 2.6K likes"
    let priceText: String      // e.g. "$29.99"

    /// Name of the artwork image in your asset catalog (optional)
    let artworkName: String?

    /// Called whenever the user taps a speed button
    let onSpeedChange: (Double) -> Void

    // MARK: - Audio engine
    @ObservedObject private var audioEngine = BeatAudioEngine.shared

    @State private var selectedSpeed: Double = 1.0
    @State private var controlFeedbackMessage: String?
    private let speeds: [Double] = [0.5, 1.0, 1.25, 1.5]

    private let accent = Color.white

    // MARK: - Init with default empty callback (so previews compile)
    init(
        title: String,
        producerName: String,
        subtitle: String,
        statsLine: String,
        priceText: String,
        artworkName: String?,
        onSpeedChange: @escaping (Double) -> Void = { speed in
            BeatAudioEngine.shared.setRate(Float(speed))
        }
    ) {
        self.title = title
        self.producerName = producerName
        self.subtitle = subtitle
        self.statsLine = statsLine
        self.priceText = priceText
        self.artworkName = artworkName
        self.onSpeedChange = onSpeedChange
    }

    var body: some View {
        VStack {
            // back button area stays at the very top via toolbar / navigation

            Spacer(minLength: 40)

            // MAIN STACK (disc + text + controls + speeds)
            VStack(spacing: 24) {

                // Galaxy disc
                BeatDiscView(
                    isPlaying: $audioEngine.isPlaying,
                    accentColor: .white
                )
                .frame(width: 260, height: 260)

                // Title / artist / stats
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Text(producerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))

                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)

                        Text("• \(subtitle)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text(statsLine)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Progress bar
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { audioEngine.currentTime },
                            set: { audioEngine.currentTime = $0 }
                        ),
                        in: 0...max(audioEngine.duration, 1)
                    )
                    .tint(.white)

                    HStack {
                        Text(timeString(from: audioEngine.currentTime))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        Text(timeString(from: audioEngine.duration))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Controls row (prev / play / next)
                HStack(spacing: 40) {
                    Button {
                        controlFeedbackMessage = "Previous beat is coming soon."
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .playerControlStyle()

                    Button {
                        if audioEngine.isPlaying {
                            audioEngine.pause()
                        } else {
                            audioEngine.play()
                        }
                    } label: {
                        ZStack {
                            GalaxyOrbBackground(isPlaying: audioEngine.isPlaying, size: 80)
                            Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        controlFeedbackMessage = "Next beat is coming soon."
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .playerControlStyle()
                }

                // Speed circles row
                HStack(spacing: 18) {
                    ForEach(speeds, id: \.self) { speed in
                        Button {
                            selectedSpeed = speed
                            audioEngine.setRate(Float(speed))
                            onSpeedChange(speed)
                        } label: {
                            ZStack {
                                GalaxyOrbBackground(isPlaying: true, size: 50)
                                Text(speedLabel(for: speed))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(selectedSpeed == speed ? 0.95 : 0.35), lineWidth: 2)
                                            .frame(width: 50, height: 50)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color.black.ignoresSafeArea())
        .alert("Coming soon", isPresented: Binding(
            get: { controlFeedbackMessage != nil },
            set: { if !$0 { controlFeedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(controlFeedbackMessage ?? "")
        }
    }

    // MARK: - Helpers

    private func timeString(from seconds: Double) -> String {
        let intSeconds = Int(seconds.rounded())
        let minutes = intSeconds / 60
        let secs = intSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func speedLabel(for speed: Double) -> String {
        switch speed {
        case 0.5: return "0.5x"
        case 1.0: return "1x"
        case 1.25: return "1.25x"
        case 1.5: return "1.5x"
        default:  return "\(speed)x"
        }
    }
}

// MARK: - Reusable control styling

private extension View {
    func playerControlStyle(isPrimary: Bool = false) -> some View {
        self
            .font(.title3.weight(.semibold))
            .foregroundColor(isPrimary ? .black : .white)
            .frame(width: isPrimary ? 64 : 44, height: isPrimary ? 64 : 44)
            .background(isPrimary ? Color.white : Color.white.opacity(0.16))
            .clipShape(Circle())
    }
}

// MARK: - Preview

struct BeatPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        BeatPlayerView(
            title: "Midnight Dreams",
            producerName: "LunarBeats",
            subtitle: "HipHop Type Beat",
            statsLine: "31.5K plays • 2.6K likes",
            priceText: "$29.99",
            artworkName: nil   // or "YourArtworkAsset"
        )
        .preferredColorScheme(.dark)
    }
}
