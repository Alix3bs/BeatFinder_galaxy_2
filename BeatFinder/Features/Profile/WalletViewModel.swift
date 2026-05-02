import Foundation

@MainActor
final class WalletViewModel: ObservableObject {
    struct Activity: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let amount: String
    }

    let cardholderName = "TRAY3BEATS"
    let cardNumber = "4242  4800  9800  1123"
    let balance = "$2,450.00"
    let activity: [Activity] = [
        Activity(title: "Beat payout", subtitle: "Today · 2:45 PM", amount: "+$45.00"),
        Activity(title: "Membership renewal", subtitle: "Yesterday", amount: "-$9.99"),
        Activity(title: "Transfer to bank", subtitle: "Feb 24", amount: "-$120.00")
    ]
}
