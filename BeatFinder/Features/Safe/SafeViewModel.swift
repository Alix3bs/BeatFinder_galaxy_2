import Foundation

@MainActor
final class SafeViewModel: ObservableObject {
    struct SafeItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String
        let date: String
    }

    @Published var items: [SafeItem] = [
        SafeItem(title: "Neon Echo", subtitle: "Matched beat · Trap · 142 BPM", date: "Saved today"),
        SafeItem(title: "Blue Room", subtitle: "Reference lock · R&B · 98 BPM", date: "Saved yesterday"),
        SafeItem(title: "Skyline Fade", subtitle: "Vault hold · Lo-Fi · 86 BPM", date: "Saved Feb 24")
    ]

    @Published var pendingDeletion: SafeItem?

    func requestDelete(_ item: SafeItem) {
        pendingDeletion = item
    }

    func cancelDeletion() {
        pendingDeletion = nil
    }

    func confirmDeletion() {
        guard let pendingDeletion else { return }
        items.removeAll { $0.id == pendingDeletion.id }
        self.pendingDeletion = nil
    }
}
