import SwiftUI

struct GalaxySignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorText: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GIFBackgroundView(gifName: "safe_galaxy.gif0.gif")
                    .ignoresSafeArea()

                Color.black.opacity(0.55).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Text("Create account")
                            .font(BeatTypography.screenTitle)
                            .foregroundStyle(.white)

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

                            GalaxyTextField(
                                placeholder: "Retype Password",
                                text: $confirmPassword,
                                isSecure: true
                            )
                        }
                        .padding(.top, 18)

                        if let errorText { Text(errorText).foregroundStyle(.red) }
                        if let err = auth.authError { Text(err).foregroundStyle(.red) }

                        PrimaryButton(title: "Create Account") {
                            Task {
                                guard !email.isEmpty, !password.isEmpty, password == confirmPassword else {
                                    errorText = "Enter email, matching passwords"
                                    return
                                }
                                do {
                                    try await auth.signUp(email: email, password: password)
                                    if auth.sessionUserId != nil { dismiss() }
                                } catch {
                                    // error is handled via auth.authError
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
