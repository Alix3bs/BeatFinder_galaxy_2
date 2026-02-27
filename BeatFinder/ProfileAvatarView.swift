import SwiftUI

struct ProfileAvatarView: View {
    var initials: String = "A"      // temporary until you hook up real user data
    
    var body: some View {
        ZStack {
            // Background circle (gradient)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.40, blue: 0.30), // orange-red
                            Color(red: 0.84, green: 0.18, blue: 0.35)  // darker red
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
            
            // Initials / fallback text
            Text(initials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

