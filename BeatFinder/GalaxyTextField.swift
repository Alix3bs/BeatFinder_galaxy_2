import SwiftUI

struct GalaxyTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
                    .keyboardType(placeholder.lowercased().contains("email") ? .emailAddress : .default)
                    .textInputAutocapitalization(.never)
            }
        }
        .foregroundColor(.white) // ✅ ACTUAL TEXT COLOR
        .padding()
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BeatLayout.controlCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
