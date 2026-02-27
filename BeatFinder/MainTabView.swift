import SwiftUI

struct MainTabView: View {
    private let tabBarBackgroundHeight: CGFloat = 56

    private enum Tab: String, CaseIterable, Hashable {
        case home = "Home"
        case upload = "Upload"
        case profile = "Profile"
        case safe = "Safe"

        var icon: String {
            switch self {
            case .home:
                return "house.fill"
            case .upload:
                return "plus.circle.fill"
            case .profile:
                return "person.circle.fill"
            case .safe:
                return "lock.shield.fill"
            }
        }
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let tabBarBottomPadding = max(8, safeBottom) + 8
            let reservedHeight = tabBarBackgroundHeight + tabBarBottomPadding + 10

            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea() // Global dark mode fill
                
                selectedTabView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.tabBarClearance, reservedHeight)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: reservedHeight)
                    }
                    .environment(\.colorScheme, .dark) // Force dark mode

                floatingTabBar(bottomPadding: tabBarBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .home:
            NavigationStack { HomeView() }
        case .upload:
            NavigationStack { UploadView() }
        case .profile:
            NavigationStack { ProfileView() }
        case .safe:
            SafeView()
        }
    }

    private func floatingTabBar(bottomPadding: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .liquidGlass(cornerRadius: 30, borderOpacity: 0.15)
        .padding(.horizontal, BeatLayout.screenHorizontal)
        .padding(.top, 8)
        .padding(.bottom, bottomPadding)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .frame(height: 22)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color(red: 0.25, green: 0.6, blue: 1.0) : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
