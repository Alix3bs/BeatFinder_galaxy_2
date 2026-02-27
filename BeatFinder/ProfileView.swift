import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var user: UserModel
    @Environment(\.tabBarClearance) private var tabBarClearance
    @State private var showSettings = false
    
    // Sample dummy user beats
    let userBeats: [FeedBeat] = [
        FeedBeat(id: UUID(), title: "Summer Breeze", artist: "You", genre: "Pop", bpm: 120, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Midnight", artist: "You", genre: "Trap", bpm: 140, price: "Get", artworkName: nil),
        FeedBeat(id: UUID(), title: "Ocean Waves", artist: "You", genre: "Lo-Fi", bpm: 85, price: "Free", artworkName: nil)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Top Banner (BandLab style)
                        ZStack(alignment: .bottomLeading) {
                            // Banner Image / Gradient
                            LinearGradient(
                                colors: [Color(red: 0.1, green: 0.2, blue: 0.5), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 180)
                            
                            // Top Right Settings Button
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        showSettings = true
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.3))
                                            .clipShape(Circle())
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            
                            // Overlapping Avatar
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.15, green: 0.35, blue: 0.85))
                                    .frame(width: 90, height: 90)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 4))
                                
                                Text(String(user.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 24, y: 45) // Push it down to overlap
                        }
                        
                        // User Info (Name, Handle, Bio)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("@\(user.username)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.25, green: 0.6, blue: 1.0)) // Blue accent
                            
                            Text(user.bio.isEmpty ? "Making beats. Living life." : user.bio)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 55) // Make room for avatar overlap
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Stats Row
                        HStack(spacing: 30) {
                            statColumn(value: "\(user.followers)", label: "Followers")
                            statColumn(value: "\(user.following)", label: "Following")
                            statColumn(value: "3", label: "Beats")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                // Edit Profile
                            } label: {
                                Text("Edit Profile")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            Button {
                                // Share
                            } label: {
                                Text("Share")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // GO+ Glass Subscription Banner
                        Button {
                            // Present subscription modal (handled globally or via state later)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Get GO+")
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundStyle(.white)
                                    Text("Unlock limitless studio tools.")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding:20
                            .liquidGlass(cornerRadius: 16, borderOpacity: 0.3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        
                        // Posts / Tracks Grid
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Tracks")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                ForEach(userBeats) { beat in
                                    UserBeatTile(beat: beat)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 30)
                        
                        Spacer(minLength: tabBarClearance + 20)
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView() // Will implement next
            }
        }
    }
    
    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// Re-using the simplified UserBeatTile
struct UserBeatTile: View {
    let beat: FeedBeat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.1, green: 0.15, blue: 0.25)) // Blue-dark tint
                .frame(height: 120)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(red: 0.25, green: 0.6, blue: 1.0).opacity(0.5))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(beat.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(beat.genre) • \(beat.bpm) BPM")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserModel())
}
