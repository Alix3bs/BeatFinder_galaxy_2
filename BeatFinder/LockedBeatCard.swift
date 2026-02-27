import SwiftUI

struct LockedBeatCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 1))

                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }

            Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(untitled)" : title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.black.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}
