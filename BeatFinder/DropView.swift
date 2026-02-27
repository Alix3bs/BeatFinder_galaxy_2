import SwiftUI



struct DropView: View {

    @Environment(\.selectedTheme) var selectedTheme

    var body: some View {

        ZStack {

            ThemeManager.backgroundGradient(for: selectedTheme)

                .ignoresSafeArea()

            VStack(spacing: 30) {

                Text("Collect rare beats")

                    .font(.largeTitle)

                    .fontWeight(.bold)

                    .foregroundColor(Color.primary)

                    .padding(.top, 40)



                Text("Discover exclusive drops and instrumentals")

                    .font(.headline)

                    .foregroundColor(Color.secondary)



                ZStack {

                    RoundedRectangle(cornerRadius: 20)

                        .fill(Color.white.opacity(0.15))

                        .frame(width: 280, height: 280)

                        .overlay(

                            VStack {

                                Image(systemName: "music.note.list")

                                    .resizable()

                                    .scaledToFit()

                                    .frame(width: 100, height: 100)

                                    .foregroundColor(.white)

                                    .padding(.top, 60)

                                Spacer()

                            }

                        )



                    VStack {

                        Spacer()

                        Text("Uncommon • Trap Beat • 8hr Cooldown")

                            .font(.caption)

                            .foregroundColor(Color.secondary)

                            .padding(.bottom, 60)

                    }

                }



                NavigationLink(destination: TradeView()) {

                    Text("Open Drop")

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

    }

}



#Preview {

    DropView()

}


