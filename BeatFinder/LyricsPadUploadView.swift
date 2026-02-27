import SwiftUI

// Simplified Lyrics pad UI (pic #9 style) for upload tab
struct LyricsPadUploadScreen: View {
    @State private var lyrics: String = ""
    @State private var isPlayingPreview = false
    @State private var feedbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // playback bar at top
            HStack {
                Button {
                    isPlayingPreview.toggle()
                } label: {
                    Image(systemName: isPlayingPreview ? "pause.fill" : "play.fill")
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                Slider(value: .constant(0.4))
                    .tint(.white)
                Text("-1:05")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.horizontal)

            TextEditor(text: $lyrics)
                .scrollContentBackground(.hidden)
                .background(Color.black)
                .foregroundColor(.white)
                .padding(.horizontal)
                .frame(maxHeight: 260)

            Spacer()

            Button {
                let trimmed = lyrics.trimmingCharacters(in: .whitespacesAndNewlines)
                feedbackMessage = trimmed.isEmpty ? "Add lyrics before saving." : "Lyrics saved locally."
            } label: {
                Text("Save Lyrics")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 16)
        .alert("Lyrics Pad", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(feedbackMessage ?? "")
        }
    }
}
