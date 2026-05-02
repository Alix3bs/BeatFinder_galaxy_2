import SwiftUI

struct HomeCommunityRow: View {
    let members: [HomeViewModel.CommunityMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(members) { member in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [member.accent, member.accent.opacity(0.28)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Text(String(member.name.prefix(1)))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .frame(width: 64, height: 64)

                            Text(member.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
