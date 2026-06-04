import Foundation

protocol BeatFinderAPITransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: BeatFinderAPITransport {}

protocol BeatFinderBackendAPIClientProtocol {
    var baseURL: URL { get }

    func health() async throws -> HealthResponse
    func searchText(query: String, detectedProducerTag: String?, topN: Int) async throws -> SearchResponse
    func searchAudio(_ request: BeatFinderAudioSearchRequest) async throws -> SearchResponse
    func searchHybrid(_ request: BeatFinderHybridSearchRequest) async throws -> SearchResponse
}

enum BeatFinderAPIError: LocalizedError, Equatable {
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "BeatFinder backend URL is invalid."
        case .invalidResponse:
            return "BeatFinder backend returned an invalid response."
        case .httpStatus(let statusCode):
            return "BeatFinder backend returned HTTP \(statusCode)."
        }
    }
}

struct BeatFinderTextSearchRequest: Encodable, Equatable {
    let query: String
    let detectedProducerTag: String?
    let topN: Int

    private enum CodingKeys: String, CodingKey {
        case query
        case detectedProducerTag = "detected_producer_tag"
        case topN = "top_n"
    }
}

struct BeatFinderAudioSearchRequest: Encodable, Equatable {
    let audioPath: String?
    let audioBase64: String?
    let audioFileName: String?
    let audioMimeType: String?
    let detectedProducerTag: String?
    let topN: Int

    init(
        audioPath: String? = nil,
        audioBase64: String? = nil,
        audioFileName: String? = nil,
        audioMimeType: String? = nil,
        detectedProducerTag: String? = nil,
        topN: Int = 3
    ) {
        self.audioPath = audioPath
        self.audioBase64 = audioBase64
        self.audioFileName = audioFileName
        self.audioMimeType = audioMimeType
        self.detectedProducerTag = detectedProducerTag
        self.topN = topN
    }

    private enum CodingKeys: String, CodingKey {
        case audioPath = "audio_path"
        case audioBase64 = "audio_base64"
        case audioFileName = "audio_file_name"
        case audioMimeType = "audio_mime_type"
        case detectedProducerTag = "detected_producer_tag"
        case topN = "top_n"
    }
}

struct BeatFinderHybridSearchRequest: Encodable, Equatable {
    let query: String?
    let audioPath: String?
    let audioBase64: String?
    let audioFileName: String?
    let audioMimeType: String?
    let detectedProducerTag: String?
    let topN: Int

    init(
        query: String? = nil,
        audioPath: String? = nil,
        audioBase64: String? = nil,
        audioFileName: String? = nil,
        audioMimeType: String? = nil,
        detectedProducerTag: String? = nil,
        topN: Int = 3
    ) {
        self.query = query
        self.audioPath = audioPath
        self.audioBase64 = audioBase64
        self.audioFileName = audioFileName
        self.audioMimeType = audioMimeType
        self.detectedProducerTag = detectedProducerTag
        self.topN = topN
    }

    private enum CodingKeys: String, CodingKey {
        case query
        case audioPath = "audio_path"
        case audioBase64 = "audio_base64"
        case audioFileName = "audio_file_name"
        case audioMimeType = "audio_mime_type"
        case detectedProducerTag = "detected_producer_tag"
        case topN = "top_n"
    }
}

final class BeatFinderAPIClient: BeatFinderBackendAPIClientProtocol {
    static let localDevelopmentBaseURL = URL(string: "http://127.0.0.1:8787")!

    let baseURL: URL

    private let transport: BeatFinderAPITransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = BeatFinderAPIClient.localDevelopmentBaseURL,
        transport: BeatFinderAPITransport = URLSession.shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = BeatFinderAPIClient.makeDecoder()
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.encoder = encoder
        self.decoder = decoder
    }

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    func health() async throws -> HealthResponse {
        let request = try makeRequest(path: "/health", method: "GET")
        return try await send(request)
    }

    func searchText(query: String, detectedProducerTag: String? = nil, topN: Int = 3) async throws -> SearchResponse {
        let body = BeatFinderTextSearchRequest(
            query: query,
            detectedProducerTag: detectedProducerTag,
            topN: topN
        )
        return try await post(path: "/search/text", body: body)
    }

    func searchAudio(_ request: BeatFinderAudioSearchRequest) async throws -> SearchResponse {
        try await post(path: "/search/audio", body: request)
    }

    func searchHybrid(_ request: BeatFinderHybridSearchRequest) async throws -> SearchResponse {
        try await post(path: "/search/hybrid", body: request)
    }
}

private extension BeatFinderAPIClient {
    func post<Body: Encodable, Response: Decodable>(path: String, body: Body) async throws -> Response {
        var request = try makeRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BeatFinderAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BeatFinderAPIError.httpStatus(http.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }

    func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = endpointURL(path: path) else {
            throw BeatFinderAPIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func endpointURL(path: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath.isEmpty ? endpointPath : "/\(basePath)\(endpointPath)"
        return components.url
    }
}
