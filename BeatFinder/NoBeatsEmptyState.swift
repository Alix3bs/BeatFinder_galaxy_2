import SwiftUI

struct NoBeatsEmptyState: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.35))

            Text("No beats were found.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
