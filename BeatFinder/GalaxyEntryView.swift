import SwiftUI

struct GalaxyEntryView: View {
    // Old UI had an "Enter" button that jumped into the app.
    // With real Supabase auth, we route it to Sign In.
    @State private var showSignIn = false
    @State private var showSignUp = false

    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        ZStack {
            GIFBackgroundView(gifName: "safe_galaxy.gif0.gif")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.30), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                Text("BeatFinder")
                    .font(BeatTypography.screenTitle)
                    .foregroundStyle(.white)
                    .shadow(radius: 10)

                Text("Find the beat. Save it. Lock it.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 6)

                PrimaryButton(title: "Enter") {
                    showSignIn = true
                }
                .padding(.top, 18)
                .padding(.horizontal, BeatLayout.screenHorizontal)

                HStack(spacing: 14) {
                    PrimaryButton(title: "Sign in", kind: .outline) {
                        showSignIn = true
                    }

                    PrimaryButton(title: "Create account") {
                        showSignUp = true
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, BeatLayout.screenHorizontal)

                Spacer().frame(height: 40)
            }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            GalaxySignInView()
                .environmentObject(auth)
        }
        .fullScreenCover(isPresented: $showSignUp) {
            GalaxySignUpView()
                .environmentObject(auth)
        }
    }
}
