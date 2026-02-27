import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UploadBeatView: View {
    private let postedBeatTitleKey = "beatfinder.postedBeatTitle"
    private let postedBeatArtworkDataKey = "beatfinder.postedBeatArtworkData"

    // Artwork
    @State private var artworkItem: PhotosPickerItem?
    @State private var artworkData: Data?

    // Audio
    @State private var audioURL: URL?

    // Metadata
    @State private var beatName: String = ""
    @State private var bpm: String = ""
    @State private var genre: String = "HipHop"

    @State private var isUploading = false
    @State private var showSuccess = false
    @State private var showAudioImporter = false

    private let genres = ["HipHop", "R&B", "Trap", "Pop", "Drill", "Afrobeat", "EDM", "Other"]

    var body: some View {
        ZStack {
            GIFBackgroundView(gifName: "safe_galaxy.gif2.gif")
                .ignoresSafeArea()

            // readability overlay
            Color.black.opacity(0.55).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Upload")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 14)

                    Text("Post a beat with artwork + audio.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    // PREVIEW CARD
                    previewCard

                    // ARTWORK PICKER
                    PhotosPicker(selection: $artworkItem, matching: .images) {
                        actionRow(icon: "photo.on.rectangle.angled", title: "Choose artwork",
                                  subtitle: artworkData == nil ? "Optional" : "Selected")
                    }
                    .onChange(of: artworkItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                await MainActor.run { artworkData = data }
                            }
                        }
                    }

                    // AUDIO PICKER
                    Button {
                        showAudioImporter = true
                    } label: {
                        actionRow(icon: "waveform", title: "Choose audio file",
                                  subtitle: audioURL == nil ? "Required (mp3, wav, m4a…)" : audioURL!.lastPathComponent)
                    }
                    .buttonStyle(.plain)

                    // METADATA
                    Group {
                        GalaxyInputField(title: "Beat name", placeholder: "Untitled if empty", text: $beatName)

                        HStack(spacing: 12) {
                            GalaxyInputField(title: "BPM", placeholder: "e.g. 140", text: $bpm, keyboardType: .numberPad)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Genre")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))

                                Menu {
                                    ForEach(genres, id: \.self) { g in
                                        Button(g) { genre = g }
                                    }
                                } label: {
                                    HStack {
                                        Text(genre)
                                            .foregroundStyle(.white)
                                            .font(.system(size: 16, weight: .semibold))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(Color.black.opacity(0.35))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // UPLOAD BUTTON
                    Button {
                        upload()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.92))

                            if isUploading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text(audioURL == nil ? "Select audio to upload" : "Upload Beat")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(height: 54)
                    }
                    .disabled(audioURL == nil || isUploading)
                    .opacity((audioURL == nil || isUploading) ? 0.55 : 1.0)
                    .padding(.top, 4)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
            }
        }
        .fileImporter(
            isPresented: $showAudioImporter,
            allowedContentTypes: [
                .mp3, .wav, .mpeg4Audio, .aiff, .audio
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                audioURL = urls.first
            case .failure:
                break
            }
        }
        .alert("Uploaded!", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your beat is ready. (Backend wiring next.)")
        }
    }

    private var previewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )

                if let data = artworkData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Artwork")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: 92, height: 92)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(beatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(untitled)" : beatName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(genre) • \(bpm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "— BPM" : "\(bpm) BPM")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Text(audioURL == nil ? "No audio selected" : "Audio ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(audioURL == nil ? .white.opacity(0.55) : .white.opacity(0.9))
            }

            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 8)
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.65))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.35))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func upload() {
        guard !isUploading else { return }
        guard audioURL != nil else { return }

        isUploading = true

        // Placeholder "upload" for launch readiness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let cleanedTitle = beatName.trimmingCharacters(in: .whitespacesAndNewlines)
            let persistedTitle = cleanedTitle.isEmpty ? "(untitled)" : cleanedTitle
            UserDefaults.standard.set(persistedTitle, forKey: postedBeatTitleKey)

            if let artworkData,
               let image = UIImage(data: artworkData),
               let compressed = image.jpegData(compressionQuality: 0.82) {
                UserDefaults.standard.set(compressed, forKey: postedBeatArtworkDataKey)
            } else {
                UserDefaults.standard.removeObject(forKey: postedBeatArtworkDataKey)
            }

            isUploading = false
            showSuccess = true
        }
    }
}

// MARK: - Galaxy input field (label + styled textfield)

struct GalaxyInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
                .foregroundColor(.white)
                .tint(.white)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
