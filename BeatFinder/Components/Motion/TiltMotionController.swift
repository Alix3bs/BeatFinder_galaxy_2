import CoreMotion
import Foundation

@MainActor
final class TiltMotionController: ObservableObject {
    struct Orientation: Equatable {
        var xDegrees: Double
        var yDegrees: Double

        static let zero = Orientation(xDegrees: 0, yDegrees: 0)
    }

    @Published private(set) var orientation: Orientation = .zero

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            orientation = Self.orientation(
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll
            )
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        orientation = .zero
    }

    static func orientation(
        pitch: Double,
        roll: Double,
        maxDegrees: Double = MotionTokens.maxTiltDegrees
    ) -> Orientation {
        let pitchDegrees = clamp((-pitch * 180 / .pi) * 0.42, maxDegrees: maxDegrees)
        let rollDegrees = clamp((roll * 180 / .pi) * 0.42, maxDegrees: maxDegrees)
        return Orientation(xDegrees: pitchDegrees, yDegrees: rollDegrees)
    }

    private static func clamp(_ value: Double, maxDegrees: Double) -> Double {
        min(max(value, -maxDegrees), maxDegrees)
    }
}
