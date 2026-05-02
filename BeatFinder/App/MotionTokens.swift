import SwiftUI

enum MotionTokens {
    static let fastDuration: Double = 0.25
    static let mediumDuration: Double = 0.32
    static let slowDuration: Double = 0.4
    static let maxTiltDegrees: Double = 7

    static let fastEase: Animation = .easeInOut(duration: fastDuration)
    static let mediumEase: Animation = .easeInOut(duration: mediumDuration)
    static let slowEase: Animation = .easeInOut(duration: slowDuration)
    static let topModalSpring: Animation = .interactiveSpring(response: 0.46, dampingFraction: 0.78, blendDuration: 0.18)
}
