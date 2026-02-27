import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var user: UserModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var showChangePhotoComingSoon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Top bar
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Text("Edit Profile")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveChanges()
                }
                .bold()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)

            // Profile photo
            Text("Profile Photo")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    )

                Button("Change Photo") {
                    showChangePhotoComingSoon = true
                }
                .foregroundColor(.orange)

                Spacer()
            }
            .padding(.horizontal, 24)

            // Fields
            VStack(alignment: .leading, spacing: 12) {
                Text("Display Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)

                Text("Username")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Text("Bio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Bio", text: $bio, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            // Prefill with current user values
            displayName = user.displayName
            username = user.username
            bio = user.bio
        }
        .alert("Coming soon", isPresented: $showChangePhotoComingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Photo picker is coming soon.")
        }
    }

    private func saveChanges() {
        // Write back into shared model
        user.displayName = displayName
        user.username = username
        user.bio = bio
        dismiss()
    }
}
