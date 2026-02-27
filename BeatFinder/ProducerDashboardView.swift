import SwiftUI

struct ProducerDashboardView: View {
    @State private var uploadedBeats: [Beat] = []
    @State private var showUploadSheet = false
    @State private var totalEarnings: Double = 0.0
    @State private var totalSales: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {

                        // PAGE TITLE
                        Text("🎛️ Producer Dashboard")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 30)

                        // EARNINGS SUMMARY
                        EarningsCard(totalEarnings: totalEarnings,
                                     totalSales: totalSales)

                        // UPLOAD BUTTON
                        Button(action: {
                            showUploadSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                Text("Upload New Beat")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(colors: [Color.purple, Color.blue],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showUploadSheet) {
                            UploadBeatDashboardView(onFinish: { beat in
                                uploadedBeats.append(beat)
                            })
                        }

                        // BEAT LIST
                        VStack(alignment: .leading, spacing: 16) {
                            Text("📂 My Beats")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            if uploadedBeats.isEmpty {
                                Text("You haven't uploaded any beats yet.")
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal)
                            } else {
                                ForEach(uploadedBeats) { beat in
                                    ProducerBeatRow(beat: beat)
                                }
                            }
                        }

                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct EarningsCard: View {
    let totalEarnings: Double
    let totalSales: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Earnings")
                .font(.headline)
                .foregroundColor(.white)

            Text("$\(String(format: "%.2f", totalEarnings))")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.green)

            Text("\(totalSales) total sales")
                .foregroundColor(.white.opacity(0.7))
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(14)
        .shadow(color: .green.opacity(0.3), radius: 10)
        .padding(.horizontal)
    }
}

struct ProducerBeatRow: View {
    let beat: Beat

    var body: some View {
        HStack(spacing: 16) {
            Image(beat.imageName)
                .resizable()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading) {
                Text(beat.title)
                    .foregroundColor(.white)
                    .font(.headline)

                if let bpm = beat.bpm, bpm > 0 && !beat.genre.isEmpty {
                    Text("\(bpm) BPM • \(beat.genre)")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                } else {
                    Text(beat.artistName)
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                }
            }
            Spacer()

            NavigationLink(destination: ThemePreviewFullView(selectedBeat: beat)) {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.cyan)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}

