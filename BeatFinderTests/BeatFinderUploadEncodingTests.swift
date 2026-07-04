import Foundation
import Testing
@testable import BeatFinder

struct BeatFinderUploadEncodingTests {
    @Test func multipartBodyContainsFieldsAndFile() throws {
        let request = BeatFinderAudioUploadRequest(
            fileData: Data([0x52, 0x49, 0x46, 0x46]),
            fileName: "late_nights.wav",
            mimeType: "audio/wav",
            query: "sza type beat",
            detectedProducerTag: "prod by salishan",
            topN: 3
        )
        let boundary = "test-boundary"
        let body = BeatFinderAPIClient.makeMultipartBody(request: request, boundary: boundary)
        let text = String(decoding: body, as: UTF8.self)

        #expect(text.contains("--test-boundary\r\n"))
        #expect(text.contains("Content-Disposition: form-data; name=\"top_n\"\r\n\r\n3"))
        #expect(text.contains("Content-Disposition: form-data; name=\"query\"\r\n\r\nsza type beat"))
        #expect(text.contains("Content-Disposition: form-data; name=\"detected_producer_tag\"\r\n\r\nprod by salishan"))
        #expect(text.contains("Content-Disposition: form-data; name=\"audio\"; filename=\"late_nights.wav\""))
        #expect(text.contains("Content-Type: audio/wav"))
        #expect(text.contains("RIFF"))
        #expect(text.hasSuffix("--test-boundary--\r\n"))
    }

    @Test func multipartBodyStripsUnsafeFilenameCharacters() throws {
        let request = BeatFinderAudioUploadRequest(
            fileData: Data([0x01]),
            fileName: "bad\"name\r\n.wav",
            mimeType: "audio/wav"
        )
        let body = BeatFinderAPIClient.makeMultipartBody(request: request, boundary: "b")
        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("filename=\"badname.wav\""))
    }

    @Test func searchAudioUploadPostsMultipartToAudioEndpoint() async throws {
        let transport = UploadCapturingTransport()
        let client = BeatFinderAPIClient(
            baseURL: URL(string: "http://127.0.0.1:8787")!,
            transport: transport
        )

        _ = try await client.searchAudioUpload(
            BeatFinderAudioUploadRequest(
                fileData: Data([0x02]),
                fileName: "clip.wav",
                mimeType: "audio/wav",
                topN: 2
            )
        )

        let request = try #require(transport.lastRequest)
        #expect(request.url?.path == "/search/audio")
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try #require(request.httpBody)
        #expect(String(decoding: body, as: UTF8.self).contains("filename=\"clip.wav\""))
    }

    @Test func searchAudioUploadWithQueryUsesHybridEndpoint() async throws {
        let transport = UploadCapturingTransport()
        let client = BeatFinderAPIClient(
            baseURL: URL(string: "http://127.0.0.1:8787")!,
            transport: transport
        )

        _ = try await client.searchAudioUpload(
            BeatFinderAudioUploadRequest(
                fileData: Data([0x03]),
                fileName: "clip.wav",
                mimeType: "audio/wav",
                query: "detroit type beat"
            )
        )

        #expect(transport.lastRequest?.url?.path == "/search/hybrid")
    }
}

private final class UploadCapturingTransport: BeatFinderAPITransport {
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let payload = Data(
            """
            {"query_id":"q1","query_type":"audio","confidence":"no_confident_exact_match","results":[]}
            """.utf8
        )
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1:8787")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (payload, response)
    }
}
