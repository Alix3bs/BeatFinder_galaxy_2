import Foundation
import Supabase

struct BeatSearchThresholds {
    let exactThreshold: Double
    let similarityThreshold: Double

    static let `default` = BeatSearchThresholds(
        exactThreshold: 0.92,
        similarityThreshold: 0.72
    )
}

enum BeatSearchError: LocalizedError {
    case notAuthenticated
    case emptyQuery
    case emptySourceURL
    case emptySnippetURL
    case snippetReadFailed
    case invalidResponse
    case missingEmbedding
    case missingFingerprintHash

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in is required to search beats."
        case .emptyQuery:
            return "Enter a beat query first."
        case .emptySourceURL:
            return "Paste a valid source URL first."
        case .emptySnippetURL:
            return "Upload or record a snippet first."
        case .snippetReadFailed:
            return "Unable to read the selected snippet file."
        case .invalidResponse:
            return "Search backend returned an invalid response."
        case .missingEmbedding:
            return "Embedding service did not return a query vector."
        case .missingFingerprintHash:
            return "Fingerprint service did not return a fingerprint hash."
        }
    }
}

private struct EmbedQueryBody: Encodable {
    let query: String
    let force_web: Bool
}

private struct FingerprintBody: Encodable {
    let snippet_url: String?
    let source_url: String?
}

final class BeatSearchService {
    static let shared = BeatSearchService()

    private let thresholds: BeatSearchThresholds

    init(thresholds: BeatSearchThresholds = .default) {
        self.thresholds = thresholds
    }

    // Flow 1:
    // Text search -> Edge Function embed_query -> RPC search_beats_by_embedding
    func searchText(query rawQuery: String, forceWeb: Bool) async throws -> BeatSearchResponse {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw BeatSearchError.emptyQuery }

        try await ensureAuthenticatedSession()

        let embedding = try await fetchQueryEmbedding(query: query, forceWeb: forceWeb)
        let rows = try await fetchEmbeddingMatches(embedding: embedding, limit: 20)
        let candidates = rows.compactMap(\.asCandidate)
        return normalize(query: query, candidates: candidates, source: .edgeFunction)
    }

    // Flow 2:
    // Audio search -> upload snippet (done by caller) -> Edge Function fingerprint -> RPC search_beats_by_fingerprint_hash
    func matchAudio(snippetURL rawSnippetURL: String?, sourceURL rawSourceURL: String?) async throws -> BeatSearchResponse {
        let snippetURL = rawSnippetURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceURL = rawSourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        if rawSourceURL != nil {
            guard let sourceURL, !sourceURL.isEmpty else { throw BeatSearchError.emptySourceURL }
        }
        if rawSnippetURL != nil {
            guard let snippetURL, !snippetURL.isEmpty else { throw BeatSearchError.emptySnippetURL }
        }
        if (snippetURL?.isEmpty ?? true) && (sourceURL?.isEmpty ?? true) {
            throw BeatSearchError.emptySnippetURL
        }

        try await ensureAuthenticatedSession()

        let hash = try await fetchFingerprintHash(snippetURL: snippetURL, sourceURL: sourceURL)
        let rows = try await fetchFingerprintMatches(hash: hash, limit: 20)
        let candidates = rows.compactMap(\.asCandidate)
        let queryLabel = sourceURL ?? snippetURL ?? "Audio snippet"
        return normalize(query: queryLabel, candidates: candidates, source: .edgeFunction)
    }

    func uploadSnippet(fileURL: URL, userId: UUID) async throws -> String {
        try await ensureAuthenticatedSession()

        let ext = normalizedSnippetExtension(from: fileURL)
        let filename = "\(UUID().uuidString).\(ext)"
        let path = "\(userId.uuidString)/\(filename)"
        let contentType = mimeType(forExtension: ext)

        let data = try readFileData(fileURL)

        try await SupabaseManager.client.storage
            .from("snippets")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: contentType, upsert: true)
            )

        let signedURL = try await SupabaseManager.client.storage
            .from("snippets")
            .createSignedURL(path: path, expiresIn: 60 * 60)

        return signedURL.absoluteString
    }
}

private extension BeatSearchService {
    struct EdgeCandidate {
        let beatID: UUID?
        let platform: BeatPlatform
        let url: String
        let title: String
        let similarity: Double
        let bpm: Int?
        let key: String?
        let note: String?
    }

    struct RPCBeatRow: Decodable {
        let beat_id: UUID?
        let id: UUID?
        let platform: String?
        let url: String?
        let source_url: String?
        let title: String?
        let similarity: Double?
        let score: Double?
        let bpm: Int?
        let key: String?
        let note: String?

        var asCandidate: EdgeCandidate? {
            guard
                let title, !title.isEmpty,
                let resolvedURL = (url ?? source_url), !resolvedURL.isEmpty
            else {
                return nil
            }

            return EdgeCandidate(
                beatID: beat_id ?? id,
                platform: BeatPlatform(rawPlatform: platform),
                url: resolvedURL,
                title: title,
                similarity: similarity ?? score ?? 0,
                bpm: bpm,
                key: key,
                note: note
            )
        }
    }

    func ensureAuthenticatedSession() async throws {
        do {
            _ = try await SupabaseManager.client.auth.session
        } catch {
            throw BeatSearchError.notAuthenticated
        }
    }

    func fetchQueryEmbedding(query: String, forceWeb: Bool) async throws -> [Double] {
        let body = EmbedQueryBody(query: query, force_web: forceWeb)
        let data = try await invokeFunctionData("embed_query", body: body)

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BeatSearchError.invalidResponse
        }

        let embedding =
            parseDoubleArray(root["embedding"]) ??
            parseDoubleArray((root["data"] as? [String: Any])?["embedding"]) ??
            parseDoubleArray((root["result"] as? [String: Any])?["embedding"]) ??
            parseDoubleArray(root["vector"]) ??
            parseDoubleArray((root["data"] as? [String: Any])?["vector"])

        guard let embedding, !embedding.isEmpty else {
            throw BeatSearchError.missingEmbedding
        }
        return embedding
    }

    func fetchFingerprintHash(snippetURL: String?, sourceURL: String?) async throws -> String {
        let body = FingerprintBody(snippet_url: snippetURL, source_url: sourceURL)
        let data = try await invokeFunctionData("fingerprint", body: body)

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BeatSearchError.invalidResponse
        }

        let hash =
            parseString(root["fingerprint_hash"]) ??
            parseString((root["data"] as? [String: Any])?["fingerprint_hash"]) ??
            parseString(root["hash"]) ??
            parseString((root["data"] as? [String: Any])?["hash"])

        guard let hash, !hash.isEmpty else {
            throw BeatSearchError.missingFingerprintHash
        }
        return hash
    }

    func fetchEmbeddingMatches(embedding: [Double], limit: Int) async throws -> [RPCBeatRow] {
        let body: [String: Any] = [
            "query_embedding": embedding,
            "match_count": max(1, min(50, limit)),
            "min_similarity": 0
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await invokeRPCData("search_beats_by_embedding", bodyData: bodyData)
        return try decodeRPCRows(data)
    }

    func fetchFingerprintMatches(hash: String, limit: Int) async throws -> [RPCBeatRow] {
        let body: [String: Any] = [
            "query_hash": hash,
            "match_count": max(1, min(50, limit))
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await invokeRPCData("search_beats_by_fingerprint_hash", bodyData: bodyData)
        return try decodeRPCRows(data)
    }

    func invokeFunctionData<Body: Encodable>(_ name: String, body: Body) async throws -> Data {
        try await SupabaseManager.client.functions.invoke(
            name,
            options: FunctionInvokeOptions(body: body),
            decode: { data, _ in data }
        )
    }

    func invokeRPCData(_ name: String, bodyData: Data) async throws -> Data {
        guard let url = URL(string: "/rest/v1/rpc/\(name)", relativeTo: SupabaseManager.url) else {
            throw BeatSearchError.invalidResponse
        }

        let session = try await SupabaseManager.client.auth.session

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(SupabaseManager.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BeatSearchError.invalidResponse
        }
        return data
    }

    func decodeRPCRows(_ data: Data) throws -> [RPCBeatRow] {
        do {
            return try JSONDecoder().decode([RPCBeatRow].self, from: data)
        } catch {
            throw BeatSearchError.invalidResponse
        }
    }

    func parseDoubleArray(_ value: Any?) -> [Double]? {
        guard let array = value as? [Any] else { return nil }
        let values = array.compactMap { element -> Double? in
            switch element {
            case let d as Double:
                return d
            case let i as Int:
                return Double(i)
            case let s as String:
                return Double(s)
            default:
                return nil
            }
        }
        return values.isEmpty ? nil : values
    }

    func parseString(_ value: Any?) -> String? {
        guard let s = value as? String else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func readFileData(_ url: URL) throws -> Data {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw BeatSearchError.snippetReadFailed
        }
    }

    func normalizedSnippetExtension(from url: URL) -> String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ext.isEmpty ? "m4a" : ext
    }

    func mimeType(forExtension ext: String) -> String {
        switch ext {
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "aac":
            return "audio/aac"
        case "caf":
            return "audio/x-caf"
        case "aif", "aiff":
            return "audio/aiff"
        case "m4a":
            return "audio/mp4"
        default:
            return "audio/m4a"
        }
    }

    func normalize(
        query: String,
        candidates: [EdgeCandidate],
        source: BeatSearchSource
    ) -> BeatSearchResponse {
        let sorted = candidates.sorted { $0.similarity > $1.similarity }
        let topCandidates = Array(sorted.prefix(12))

        let matches = topCandidates.map { candidate in
            let verdict: BeatMatchVerdict
            if candidate.similarity >= thresholds.exactThreshold {
                verdict = .exact
            } else if candidate.similarity >= thresholds.similarityThreshold {
                verdict = .similar
            } else {
                verdict = .lowConfidence
            }

            return BeatSearchMatch(
                remoteMatchID: candidate.beatID,
                platform: candidate.platform,
                url: candidate.url,
                title: candidate.title,
                similarity: candidate.similarity,
                bpm: candidate.bpm,
                key: candidate.key,
                verdict: verdict,
                note: candidate.note
            )
        }

        let resultState: BeatSearchResultState
        if let best = matches.first, best.similarity >= thresholds.exactThreshold {
            resultState = .exactMatch
        } else if matches.contains(where: { $0.similarity >= thresholds.similarityThreshold }) {
            resultState = .closeMatches
        } else {
            resultState = .notFound
        }

        let summary: String
        switch resultState {
        case .exactMatch:
            summary = "Exact match found in indexed beats."
        case .closeMatches:
            summary = "Close matches found. Review top candidates."
        case .notFound:
            summary = "Not found in current index. Try another query or audio snippet."
        }

        return BeatSearchResponse(
            query: query,
            source: source,
            resultState: resultState,
            likelyCustom: resultState == .notFound,
            summary: summary,
            matches: matches
        )
    }
}
