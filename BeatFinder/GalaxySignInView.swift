import SwiftUI

struct GalaxySignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GIFBackgroundView(gifName: "safe_galaxy.gif0.gif")
                    .ignoresSafeArea()

                Color.black.opacity(0.55).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Text("BeatFinder")
                            .font(BeatTypography.screenTitle)
                            .foregroundStyle(.white)

                        Text("Welcome back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        VStack(spacing: 16) {
                            GalaxyTextField(
                                placeholder: "Email",
                                text: $email
                            )

                            GalaxyTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true
                            )
                        }
                        .padding(.top, 18)

                        if let errorText { Text(errorText).foregroundStyle(.red) }
                        if let err = auth.authError { Text(err).foregroundStyle(.red) }

                        PrimaryButton(title: "Sign In") {
                            Task {
                                guard !email.isEmpty, !password.isEmpty else {
                                    errorText = "Enter email + password"
                                    return
                                }
                                do {
                                    try await auth.signIn(email: email, password: password)
                                    if auth.sessionUserId != nil { dismiss() }
                                } catch {
                                    // handled via auth.authError
                                }
                            }
                        }
                        .padding(.top, 4)

                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(minHeight: 44)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, BeatLayout.screenHorizontal)
                    .padding(.top, max(24, proxy.safeAreaInsets.top + 12))
                    .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 14))
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }
}
