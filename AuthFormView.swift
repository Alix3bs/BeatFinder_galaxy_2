import SwiftUI

struct AuthFormView: View {
    enum Mode { case signIn, signUp }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore

    let mode: Mode

    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var errorText: String?

    var title: String { mode == .signIn ? "Sign in" : "Create account" }
    var actionTitle: String { mode == .signIn ? "Sign In" : "Create Account" }

    var body: some View {
        ZStack {
            Image("safe_galaxy0") // same background
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Button("Back") { dismiss() }
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }

                Spacer()

                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)

                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }

                Button(actionTitle) {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .controlSize(.large)
                .disabled(loading)

                Spacer()
            }
            .padding(20)
        }
    }

    private func submit() async {
        errorText = nil

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorText = "Enter email and password"
            return
        }

        loading = true
        defer { loading = false }

        do {
            if mode == .signIn {
                try await auth.signIn(email: email, password: password)
            } else {
                try await auth.signUp(email: email, password: password)
            }
        } catch {
            // authError will be set inside AuthStore as well
        }

        if let err = auth.authError {
            errorText = err
        } else {
            dismiss() // success -> RootView will switch into ContentView
        }
    }
}

#Preview {
    AuthFormView(mode: .signIn).environmentObject(AuthStore())
}
