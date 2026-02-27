import SwiftUI

struct LaunchFlowView: View {
    @State private var phase: SplashPhase = .start
    @State private var showHome = false

    enum SplashPhase {
        case start
        case logoAppear
        case logoExpand
        case textFlyIn
        case stamp
        case splitZoom
    }

    var body: some View {
        if showHome {
            ContentView()
        } else {
            splashAnimation
        }
    }

    private var splashAnimation: some View {
        ZStack {
            // Background Layer
            if phase == .start || phase == .logoAppear {
                Color.white.ignoresSafeArea()
            } else {
                // Background changes / selectively reveals galaxy
                ZStack {
                    AnimatedGalaxyCapsule().ignoresSafeArea()
                    Color.black.opacity(phase == .splitZoom ? 1 : 0.4).ignoresSafeArea()
                }
            }

            // Elements Layer
            ZStack {
                // Background Logo Expanding
                if phase.rawValue >= SplashPhase.logoExpand.rawValue {
                    Image(systemName: "waveform.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.blue.opacity(0.8))
                        .scaleEffect(phase == .splitZoom ? 20 : (phase == .logoExpand ? 1.5 : 2))
                        .opacity(phase == .splitZoom ? 0 : 0.6)
                        .blur(radius: phase.rawValue >= SplashPhase.stamp.rawValue ? 10 : 0)
                }

                // Foreground Text
                if phase.rawValue >= SplashPhase.textFlyIn.rawValue {
                    Text("beatfinder")
                        .font(.custom("HelveticaNeue-CondensedBlack", size: 48))
                        .italic()
                        .foregroundStyle(.white)
                        .tracking(phase == .stamp ? 2 : 10)
                        .scaleEffect(phase == .textFlyIn ? 3 : (phase == .stamp ? 1 : 1.2))
                        .opacity(phase == .textFlyIn ? 0 : (phase == .splitZoom ? 0 : 1))
                        .shadow(color: .blue, radius: phase == .stamp ? 20 : 0, x: 0, y: 0)
                        // Split/Zoom effect
                        .offset(y: phase == .splitZoom ? -200 : 0)
                        .blur(radius: phase == .splitZoom ? 20 : 0)
                }

                // Initial Logo Appearance
                if phase == .logoAppear {
                    Image(systemName: "waveform.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.black)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            runAnimationSequence()
        }
    }

    private func runAnimationSequence() {
        // Total duration requirement: ~2.5s
        
        // 0.2s: White screen -> Logo appears
        withAnimation(.easeOut(duration: 0.3)) {
            phase = .logoAppear
        }
        
        // 0.5s: Logo Expands, Galaxy reveals behind it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .logoExpand
            }
        }
        
        // 1.0s: Text flies into center
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                phase = .textFlyIn
            }
        }
        
        // 1.5s: Stamp
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.5)) {
                phase = .stamp
            }
        }
        
        // 2.0s: Splits and Zoom into Entry/Home
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                phase = .splitZoom
            }
        }

        // 2.5s: Complete and show home
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showHome = true
        }
    }
}

extension LaunchFlowView.SplashPhase {
    var rawValue: Int {
        switch self {
        case .start: return 0
        case .logoAppear: return 1
        case .logoExpand: return 2
        case .textFlyIn: return 3
        case .stamp: return 4
        case .splitZoom: return 5
        }
    }
}

#Preview {
    LaunchFlowView()
}
