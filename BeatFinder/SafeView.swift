import SwiftUI

struct SafeView: View {
    @Environment(\.tabBarClearance) private var tabBarClearance
    
    struct Transaction: Identifiable {
        let id = UUID()
        let name: String
        let date: String
        let amount: String
        let isPositive: Bool
    }
    
    let transactions: [Transaction] = [
        .init(name: "Beat Sale - Summer Breeze", date: "Today, 2:45 PM", amount: "+$45.00", isPositive: true),
        .init(name: "Withdrawal to Bank", date: "Yesterday", amount: "-$120.00", isPositive: false),
        .init(name: "GO+ Subscription", date: "Oct 12", amount: "-$9.99", isPositive: false),
        .init(name: "Beat Sale - Midnight", date: "Oct 10", amount: "+$25.00", isPositive: true)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Header
                        HStack {
                            Text("Safe")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            
                            Button {} label: {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Main Balance Glass Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Total Balance")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text("$2,450.00")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            
                            // Mock Chart Line (Using Sparkline shape or just a styled path for demo)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 40))
                                path.addCurve(to: CGPoint(x: 50, y: 20), control1: CGPoint(x: 20, y: 40), control2: CGPoint(x: 30, y: 20))
                                path.addCurve(to: CGPoint(x: 100, y: 25), control1: CGPoint(x: 70, y: 20), control2: CGPoint(x: 80, y: 25))
                                path.addCurve(to: CGPoint(x: 150, y: 10), control1: CGPoint(x: 120, y: 25), control2: CGPoint(x: 130, y: 10))
                                path.addCurve(to: CGPoint(x: 200, y: 30), control1: CGPoint(x: 170, y: 10), control2: CGPoint(x: 180, y: 30))
                                path.addCurve(to: CGPoint(x: 250, y: 0), control1: CGPoint(x: 220, y: 30), control2: CGPoint(x: 230, y: 0))
                                path.addCurve(to: CGPoint(x: 300, y: 15), control1: CGPoint(x: 270, y: 0), control2: CGPoint(x: 280, y: 15))
                            }
                            .stroke(
                                LinearGradient(colors: [Color(red: 0.25, green: 0.6, blue: 1.0), .white], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                            .frame(height: 50)
                            .padding(.vertical, 10)
                            
                            HStack(spacing: 12) {
                                Button {} label: {
                                    Text("Withdraw")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                }
                                
                                Button {} label: {
                                    Text("Add Funds")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(24)
                        .liquidGlass(cornerRadius: 24, borderOpacity: 0.2)
                        .padding(.horizontal, 20)
                        
                        // Recent Activity
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Activity")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                            
                            VStack(spacing: 12) {
                                ForEach(transactions) { txn in
                                    HStack(spacing: 16) {
                                        // Icon
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 46, height: 46)
                                            
                                            Image(systemName: txn.isPositive ? "arrow.down.left" : "arrow.up.right")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(txn.isPositive ? Color(red: 0.2, green: 0.8, blue: 0.4) : .white)
                                        }
                                        
                                        // Details
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(txn.name)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text(txn.date)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                        
                                        // Amount
                                        Text(txn.amount)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(txn.isPositive ? Color(red: 0.2, green: 0.8, blue: 0.4) : .white)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        
                        Spacer(minLength: tabBarClearance + 20)
                    }
                }
            }
        }
    }
}

#Preview {
    SafeView()
}
