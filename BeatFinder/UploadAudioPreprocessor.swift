import AVFoundation
import Foundation

enum UploadPreprocessingError: LocalizedError, Equatable {
    case missingAudioFile
    case unreadableAudio
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .missingAudioFile:
            return "Select an audio file before searching."
        case .unreadableAudio:
            return "This audio file could not be read."
        case .conversionFailed:
            return "This audio file could not be prepared for search."
        }
    }
}

/// Converts any AVFoundation-decodable audio file into the exact format the
/// BeatFinder backend ingests: 16 kHz mono 16-bit PCM WAV, capped in length.
///
/// Converting on-device keeps uploads small and predictable (about 32 KB per
/// second of audio) and lets users submit m4a/mp3/caf recordings even though
/// the retrieval engine only decodes WAV natively.
enum UploadAudioPreprocessor {
    static let targetSampleRate: Double = 16_000
    static let maxUploadSeconds: Double = 90
    static let backendMIMEType = "audio/wav"

    static func makeBackendWAV(
        from sourceURL: URL,
        maxSeconds: Double = UploadAudioPreprocessor.maxUploadSeconds
    ) async throws -> URL {
        let boundedSeconds = max(1, maxSeconds)
        return try await Task.detached(priority: .userInitiated) {
            try convertToWAV(from: sourceURL, maxSeconds: boundedSeconds)
        }.value
    }

    static func convertToWAV(from sourceURL: URL, maxSeconds: Double) throws -> URL {
        let inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw UploadPreprocessingError.unreadableAudio
        }

        let inputFormat = inputFile.processingFormat
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: true
            ),
            let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else {
            throw UploadPreprocessingError.conversionFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("beatfinder-upload-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(
                forWriting: outputURL,
                settings: outputSettings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
        } catch {
            throw UploadPreprocessingError.conversionFailed
        }

        var reachedEnd = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if reachedEnd {
                outStatus.pointee = .endOfStream
                return nil
            }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 8_192) else {
                reachedEnd = true
                outStatus.pointee = .endOfStream
                return nil
            }
            do {
                try inputFile.read(into: buffer)
            } catch {
                reachedEnd = true
                outStatus.pointee = .endOfStream
                return nil
            }
            if buffer.frameLength == 0 {
                reachedEnd = true
                outStatus.pointee = .endOfStream
                return nil
            }
            outStatus.pointee = .haveData
            return buffer
        }

        let maxOutputFrames = AVAudioFramePosition(targetSampleRate * maxSeconds)
        var writtenFrames: AVAudioFramePosition = 0

        while writtenFrames < maxOutputFrames {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 4_096) else {
                throw UploadPreprocessingError.conversionFailed
            }

            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: inputBlock)
            if conversionError != nil {
                cleanUpPartialOutput(at: outputURL)
                throw UploadPreprocessingError.conversionFailed
            }
            if outputBuffer.frameLength == 0 {
                break
            }

            let remaining = maxOutputFrames - writtenFrames
            if AVAudioFramePosition(outputBuffer.frameLength) > remaining {
                outputBuffer.frameLength = AVAudioFrameCount(remaining)
            }

            do {
                try outputFile.write(from: outputBuffer)
            } catch {
                cleanUpPartialOutput(at: outputURL)
                throw UploadPreprocessingError.conversionFailed
            }
            writtenFrames += AVAudioFramePosition(outputBuffer.frameLength)

            if status == .endOfStream || status == .inputRanDry {
                break
            }
        }

        guard writtenFrames > 0 else {
            cleanUpPartialOutput(at: outputURL)
            throw UploadPreprocessingError.conversionFailed
        }
        return outputURL
    }

    private static func cleanUpPartialOutput(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
