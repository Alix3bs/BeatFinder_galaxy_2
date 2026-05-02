import SwiftUI

struct MembershipLogoLoop<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var floating = false
    @State private var rotating = false

    var body: some View {
        content
            .offset(y: floating ? -5 : 5)
            .rotationEffect(.degrees(rotating ? 4 : -4))
            .onAppear {
                floating = true
                rotating = true
            }
            .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: floating)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: rotating)
    }
}
