import SwiftUI

enum UploadOrbitState: Hashable {
    case idle
    case analyzing
    case matched

    var revolutionDuration: Double {
        switch self {
        case .idle:
            return 18
        case .analyzing:
            return 6
        case .matched:
            return 10
        }
    }

    var centerSymbol: String {
        switch self {
        case .idle:
            return "waveform"
        case .analyzing:
            return "waveform.path.ecg"
        case .matched:
            return "checkmark"
        }
    }
}

struct OrbitingIconField: View {
    let state: UploadOrbitState

    private let symbols = [
        "applelogo",
        "music.note",
        "headphones",
        "waveform",
        "play.rectangle.fill",
        "dot.radiowaves.left.and.right",
        "mic.fill",
        "sparkles"
    ]

    @State private var baseAngle: Double = 0
    @State private var phaseStartDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let angle = currentAngle(at: timeline.date)
            let pulse = state == .analyzing ? 1.0 + 0.05 * sin(time * 4.4) : 1.0

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 288, height: 288)

                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 204, height: 204)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.58, blue: 0.96).opacity(0.78),
                                Color(red: 0.07, green: 0.11, blue: 0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: state.centerSymbol)
                            .font(.system(size: state == .matched ? 34 : 30, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .scaleEffect(pulse)
                    .shadow(color: Color.white.opacity(state == .analyzing ? 0.16 : 0.08), radius: 14, x: 0, y: 10)

                ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                    let iconAngle = angle + (Double(index) / Double(symbols.count)) * .pi * 2
                    orbitIcon(symbol: symbol, angle: iconAngle)
                }
            }
        }
        .onAppear {
            phaseStartDate = Date()
        }
        .onChange(of: state) { _, _ in
            let now = Date()
            baseAngle = currentAngle(at: now)
            phaseStartDate = now
        }
    }

    private func orbitIcon(symbol: String, angle: Double) -> some View {
        let radius: CGFloat = 144
        let x = cos(angle) * radius
        let y = sin(angle) * radius

        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.88))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
        }
        .frame(width: 46, height: 46)
        .offset(x: x, y: y)
    }

    private func currentAngle(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(phaseStartDate)
        let progress = elapsed / state.revolutionDuration
        return baseAngle + progress * .pi * 2
    }
}
