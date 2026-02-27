import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let name: String
    let preview: String
    let time: String
}

struct MessagesView: View {
    @State private var showComposerComingSoon = false

    let messages: [Message] = [
        .init(name: "Producer 1", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 2", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 3", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 4", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 5", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 6", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 7", preview: "This beat goes crazy 🔥", time: "21 min"),
        .init(name: "Producer 8", preview: "This beat goes crazy 🔥", time: "21 min")
    ]

    var body: some View {
        VStack(spacing: 0) {

            // Top Bar
            HStack {
                Text("Messages")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // + Button
                Button {
                    showComposerComingSoon = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color(red: 1, green: 0.35, blue: 0.30))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                Text("Search")
                    .foregroundColor(.gray)

                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Messages List
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    ForEach(messages) { msg in
                        HStack {

                            // Avatar
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(msg.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)

                                Text(msg.preview)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(msg.time)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 10)
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .alert("Coming soon", isPresented: $showComposerComingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("New message composer is coming soon.")
        }
    }
}
