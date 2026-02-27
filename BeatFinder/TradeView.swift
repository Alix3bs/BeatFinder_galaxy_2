import SwiftUI



struct TradeView: View {

    @Environment(\.selectedTheme) var selectedTheme
    @State private var showTradeConfirmed = false

    var body: some View {

        ZStack {

            ThemeManager.backgroundGradient(for: selectedTheme)

                .ignoresSafeArea()



            VStack(spacing: 25) {

                Text("Trade with millions of music fans")

                    .font(.title2)

                    .fontWeight(.bold)

                    .foregroundColor(Color.primary)

                    .multilineTextAlignment(.center)

                    .padding(.horizontal, 40)

                    .padding(.top, 40)

                

                // Offer Card

                VStack(alignment: .leading, spacing: 10) {

                    Text("New Offer")

                        .font(.headline)

                        .foregroundColor(Color.secondary)

                    

                    HStack {

                        VStack(alignment: .leading) {

                            Text("saintpatty is offering")

                                .font(.caption)

                                .foregroundColor(Color.secondary)

                            Text("Those Shoes")

                                .font(.headline)

                                .foregroundColor(Color.primary)

                            Text("Good Night Moon")

                                .font(.subheadline)

                                .foregroundColor(ThemeManager.accentColor(for: selectedTheme))

                        }

                        Spacer()

                        Text("RARE")

                            .font(.caption2)

                            .padding(6)

                            .background(Color.orange)

                            .foregroundColor(.black)

                            .cornerRadius(8)

                    }

                    .padding()

                    .background(Color.white.opacity(0.1))

                    .cornerRadius(12)

                }

                .padding(.horizontal, 25)

                

                // User offering

                VStack(alignment: .leading, spacing: 10) {

                    Text("You're offering")

                        .font(.headline)

                        .foregroundColor(Color.secondary)

                    

                    VStack(spacing: 12) {

                        TradeSongCard(title: "I just, I really", artist: "EVELINE", rarity: "Common", color: .green)

                        TradeSongCard(title: "Cardiogram", artist: "EVELINE", rarity: "Uncommon", color: .purple)

                    }

                }

                .padding(.horizontal, 25)



                Spacer()

                

                // Confirm Button

                Button(action: {
                    showTradeConfirmed = true

                }) {

                    Text("Confirm")

                        .font(.headline)

                        .foregroundColor(.black)

                        .frame(maxWidth: .infinity)

                        .padding()

                        .background(ThemeManager.accentColor(for: selectedTheme))

                        .cornerRadius(14)

                        .padding(.horizontal, 40)

                }



                Spacer()

            }

        }
        .alert("Trade confirmed", isPresented: $showTradeConfirmed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your trade request has been submitted.")
        }

    }

}



struct TradeSongCard: View {

    var title: String

    var artist: String

    var rarity: String

    var color: Color



    var body: some View {

        HStack {

            VStack(alignment: .leading) {

                Text(title)

                    .font(.headline)

                    .foregroundColor(Color.primary)

                Text(artist)

                    .font(.subheadline)

                    .foregroundColor(Color.secondary)

            }

            Spacer()

            Text(rarity)

                .font(.caption)

                .padding(6)

                .background(color)

                .foregroundColor(.black)

                .cornerRadius(8)

        }

        .padding()

        .background(Color.white.opacity(0.1))

        .cornerRadius(12)

    }

}



#Preview {

    TradeView()

}

