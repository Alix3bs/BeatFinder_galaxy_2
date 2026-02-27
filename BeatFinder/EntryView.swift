import SwiftUI

struct EntryView: View {
    var onSignedIn: () -> Void

    var body: some View {
        ZStack {
            GIFBackgroundView(gifName: "safe_galaxy.gif")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("BeatFinder")
                    .foregroundStyle(.white)
                    .font(.system(size: 34, weight: .bold))

                Text("Find the beat. Save it. Lock it.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Button("Continue") {
                    onSignedIn()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

#Preview {
    EntryView(onSignedIn: {})
}
