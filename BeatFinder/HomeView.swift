import SwiftUI

struct HomeView: View {
    @State private var selectedFilter: String = "For You"
    @State private var selectedChip: String = "All"
    
    // Sample data
    let categories = ["All", "Hip Hop", "R&B", "Trap", "Lo-Fi", "Pop"]
    let producers = ["Nova", "Sage", "Rico", "Kai", "Velvet", "Rama"]
    
    // Dummy posts mimicking the ExploreMockData
    let posts: [FeedBeat] = [
        FeedBeat(id: UUID(), title: "Night Drive", artist: "Kai", genre: "Lo-Fi", bpm: 84, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Blue Tape", artist: "Nova", genre: "Boom Bap", bpm: 90, price: "Free", artworkName: nil),
        FeedBeat(id: UUID(), title: "Amber", artist: "Sage", genre: "R&B", bpm: 98, price: "Get", artworkName: nil)
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header area
                VStack(spacing: 16) {
                    HStack {
                        Text("Community")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 16)
                    
                    // Avatar Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // "Add" avatar
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.15, green: 0.35, blue: 0.85)) // BLUE THEME
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                Text("Add")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            
                            ForEach(producers, id: \.self) { producer in
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 64, height: 64)
                                        Text(String(producer.prefix(1)))
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.25, green: 0.6, blue: 1.0), lineWidth: producer == "Nova" ? 2 : 0) // BLUE RING
                                    )
                                    
                                    Text(producer)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Filter Toggle (For You / Followed) + Category Chips
                    VStack(spacing: 12) {
                        HStack(spacing: 24) {
                            ForEach(["For You", "Followed"], id: \.self) { filter in
                                Button(action: { selectedFilter = filter }) {
                                    VStack(spacing: 6) {
                                        Text(filter)
                                            .font(.system(size: 15, weight: selectedFilter == filter ? .bold : .semibold))
                                            .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.5))
                                        
                                        if selectedFilter == filter {
                                            Capsule()
                                                .fill(Color(red: 0.25, green: 0.6, blue: 1.0)) // BLUE THEME INDICATOR
                                                .frame(width: 40, height: 3)
                                        } else {
                                            Color.clear.frame(height: 3)
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: { selectedChip = category }) {
                                        Text(category)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(selectedChip == category ? .black : .white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(selectedChip == category ? Color(red: 0.25, green: 0.6, blue: 1.0) : Color.white.opacity(0.1)) // BLUE THEME SELECTED
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.black)
                .zIndex(1)
                
                // Feed
                TabView {
                    ForEach(posts) { post in
                        BeatFeedCardView(beat: post)
                            // Re-tinting the background slightly blue-dark
                            .background(Color(red: 0.05, green: 0.1, blue: 0.2)) 
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    HomeView()
}
