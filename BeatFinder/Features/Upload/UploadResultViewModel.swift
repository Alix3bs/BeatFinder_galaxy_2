import Foundation

@MainActor
final class UploadResultViewModel: ObservableObject {
    let model: BeatResultModel

    init(model: BeatResultModel) {
        self.model = model
    }

    var previewVideoID: String? {
        model.youtubeVideoID
    }

    var watchURL: URL? {
        if let direct = model.youtubeWatchURLString, let url = URL(string: direct) {
            return url
        }

        if let videoID = model.youtubeVideoID {
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [
            URLQueryItem(name: "search_query", value: "\(model.title) \(model.artist)")
        ]
        return components?.url
    }

    var releaseDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: model.releaseDate)
    }
}
