import SwiftUI

struct SafeDeleteConfirmationView: View {
    let itemTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        LiquidGlassCard(cornerRadius: 28, contentPadding: 20, fillOpacity: 0.08) {
            VStack(spacing: 16) {
                Text("Delete from Safe?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("\"\(itemTitle)\" will be removed from your locked list.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    LiquidGlassButton(action: onCancel, cornerRadius: 18, fillOpacity: 0.06) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .bold))
                    }

                    Button(action: onConfirm) {
                        Text("Delete")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("safe.confirmDelete")
                }
            }
        }
        .frame(maxWidth: 360)
    }
}
