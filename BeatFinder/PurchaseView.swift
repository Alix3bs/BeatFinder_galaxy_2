import SwiftUI

struct PurchaseView: View {
    let beat: Beat
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding()
                
                Image(beat.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .purple.opacity(0.4), radius: 10)
                
                Text(beat.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("by \(beat.artistName)")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.subheadline)
                
                if let bpm = beat.bpm, bpm > 0 && !beat.genre.isEmpty {
                    Text("\(bpm) BPM • \(beat.genre)")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.footnote)
                } else {
                    Text(beat.price)
                        .foregroundColor(.white.opacity(0.6))
                        .font(.footnote)
                }
                
                Divider().background(.white.opacity(0.2))
                    .padding(.vertical, 10)
                
                VStack(spacing: 15) {
                    Text("License Options")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        LicenseButton(title: "MP3 Lease", price: beat.price)
                        LicenseButton(title: "WAV Lease", price: "$40")
                        LicenseButton(title: "Exclusive", price: "$120")
                    }
                }
                
                Spacer()
                
                if isProcessing {
                    ProgressView("Processing Payment...")
                        .tint(.white)
                        .foregroundColor(.white)
                } else if showSuccess {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Purchase Complete!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    Button(action: startCheckout) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Pay with Apple Pay")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [Color.green, Color.teal],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.5), radius: 10)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    func startCheckout() {
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isProcessing = false
            showSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}

struct LicenseButton: View {
    let title: String
    let price: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Text(price)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color.purple.opacity(0.4), Color.black.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

