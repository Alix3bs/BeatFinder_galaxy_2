import SwiftUI

/// Deprecated compatibility wrapper.
/// Real auth flow is handled by AuthGateView + GalaxySignInView/GalaxySignUpView.
struct AuthView: View {
    var initialMode: Bool = false // true = sign up, false = sign in

    var body: some View {
        Group {
            if initialMode {
                GalaxySignUpView()
            } else {
                GalaxySignInView()
            }
        }
    }
}
