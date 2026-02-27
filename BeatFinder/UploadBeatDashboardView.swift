import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct UploadBeatDashboardView: View {
    @Environment(\.dismiss) var dismiss

    private let postedBeatTitleKey = "beatfinder.postedBeatTitle"
    private let postedBeatArtworkDataKey = "beatfinder.postedBeatArtworkData"

    @State private var title = ""
    @State private var bpm = ""
    @State private var genre = ""
    @State private var price = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var selectedURL: URL?
    @State private var showFilePicker = false

    var onFinish: (Beat) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Beat Info")) {
                    TextField("Title", text: $title)
                    TextField("BPM", text: $bpm)
                        .keyboardType(.numberPad)
                    TextField("Genre", text: $genre)
                    TextField("Price ($)", text: $price)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Cover Art")) {
                    Button("Select Image") {
                        showImagePicker = true
                    }

                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(10)
                    }
                }

                Section(header: Text("Audio File")) {
                    Button("Select Beat File (.mp3, .wav)") {
                        showFilePicker = true
                    }

                    if let url = selectedURL {
                        Text(url.lastPathComponent)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Upload Beat") {
                    let newBeat = Beat(
                        title: title,
                        artistName: "You",
                        genre: genre,
                        price: "$\(price)",
                        plays: "0",
                        likes: "0",
                        imageName: "beat1", // Placeholder for now
                        isVerified: false,
                        bpm: Int(bpm) ?? 120
                    )

                    let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let persistedTitle = cleanedTitle.isEmpty ? "(untitled)" : cleanedTitle
                    UserDefaults.standard.set(persistedTitle, forKey: postedBeatTitleKey)

                    if let selectedImage,
                       let compressed = selectedImage.jpegData(compressionQuality: 0.82) {
                        UserDefaults.standard.set(compressed, forKey: postedBeatArtworkDataKey)
                    } else {
                        UserDefaults.standard.removeObject(forKey: postedBeatArtworkDataKey)
                    }

                    onFinish(newBeat)
                    dismiss()
                }
                .disabled(title.isEmpty || bpm.isEmpty || genre.isEmpty || price.isEmpty || selectedURL == nil)
            }
            .navigationTitle("Upload Beat")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result {
                    selectedURL = urls.first
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
