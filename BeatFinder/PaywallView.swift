import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var sub: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var animateIn = false
    @State private var selectedPlan: Int = 1 // 0 = Monthly, 1 = Yearly
    
    private let features: [String] = [
        "Unlimited beat search and discovery",
        "Save and sync favorites across sessions",
        "Advanced matching and filter controls",
        "Priority access to new pro features"
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Background Header (Galaxy/Gradient)
            VStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.5), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 350)
                .mask {
                    LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack {
                // Top Header actions
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Sliding Content
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Get GO+")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(.white)
                        
                        Text("Unlock limitless studio tools.")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(Color(red: 0.25, green: 0.6, blue: 1.0))
                                
                                Text(feature)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Glass Plan Cards (Mocking StoreKit for UI consistency)
                    HStack(spacing: 16) {
                        planCard(title: "Monthly", price: "$9.99/mo", index: 0)
                        planCard(title: "Yearly", price: "$79.99/yr", subtitle: "Save 33%", index: 1, isBest: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // CTA Button
                    Button {
                        // Subscribe action
                        // Mock standard dismiss
                        dismiss()
                    } label: {
                        Text("Subscribe Now")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.25, green: 0.6, blue: 1.0))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Button("Terms") { }
                        Text("•").foregroundStyle(.white.opacity(0.5))
                        Button("Privacy") { }
                        Text("•").foregroundStyle(.white.opacity(0.5))
                        Button("Restore") { Task { await sub.restore() } }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 30)
                }
                .offset(y: animateIn ? 0 : 400) // Slide up animation
                .opacity(animateIn ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
    
    private func planCard(title: String, price: String, subtitle: String? = nil, index: Int, isBest: Bool = false) -> some View {
        let isSelected = selectedPlan == index
        
        return Button {
            withAnimation(.snappy) {
                selectedPlan = index
            }
        } label: {
            VStack(spacing: 6) {
                if isBest {
                    Text("BEST VALUE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.25, green: 0.6, blue: 1.0))
                        .clipShape(Capsule())
                        .offset(y: -15)
                        .padding(.bottom, -15)
                        .zIndex(1)
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(price)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(isSelected ? Color(red: 0.25, green: 0.6, blue: 1.0) : .white)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        // Spacer replacement to match height
                        Text(" ")
                            .font(.system(size: 12))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white.opacity(isSelected ? 0.15 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isSelected ? Color(red: 0.25, green: 0.6, blue: 1.0) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
