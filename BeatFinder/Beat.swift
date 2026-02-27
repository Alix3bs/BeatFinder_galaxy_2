import Foundation

struct Beat: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artistName: String
    let genre: String
    let price: String
    let plays: String
    let likes: String
    let imageName: String   // for now we'll use system images or assets
    let isVerified: Bool
    let bpm: Int?  // Optional for backward compatibility
    
    // Computed property for backward compatibility with old "artist" property
    var artist: String {
        return artistName
    }
}

// TEMP MOCK DATA – replace with real data later
let mockBeatsFollowing: [Beat] = [
    Beat(title: "Midnight Dreams",
         artistName: "LunarBeats",
         genre: "HipHop",
         price: "$29.99",
         plays: "31.5K",
         likes: "2.6K",
         imageName: "circle.fill",
         isVerified: true,
         bpm: 140),
    Beat(title: "Ocean Waves",
         artistName: "Tidal Sounds",
         genre: "R&B",
         price: "$24.99",
         plays: "18.2K",
         likes: "1.9K",
         imageName: "circle.fill",
         isVerified: true,
         bpm: 120),
    Beat(title: "Golden Hour",
         artistName: "Neon Keys",
         genre: "Pop",
         price: "$19.99",
         plays: "12.4K",
         likes: "1.2K",
         imageName: "circle.fill",
         isVerified: false,
         bpm: 110)
]

let mockBeatsTrending: [Beat] = [
    Beat(title: "Drift",
         artistName: "Tray3Beats",
         genre: "Trap",
         price: "$39.99",
         plays: "54.2K",
         likes: "4.3K",
         imageName: "circle.fill",
         isVerified: true,
         bpm: 145),
    Beat(title: "Low Lights",
         artistName: "LoFi Lane",
         genre: "Lo-Fi",
         price: "$14.99",
         plays: "22.1K",
         likes: "1.7K",
         imageName: "circle.fill",
         isVerified: false,
         bpm: 85)
]

