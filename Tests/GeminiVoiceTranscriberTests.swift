import Foundation
import Testing
@testable import fixer

@Suite(.serialized)
struct GeminiVoiceTranscriberTests {
    @Test func sendsInlineAudioWithFixedMultilingualPolicy() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.queue = [
            .init(
                statusCode: 200,
                data: #"{"candidates":[{"content":{"parts":[{"text":"  Привет, world!\n"}]}}]}"#.data(using: .utf8)!
            )
        ]
        let api = GeminiAPI(
            session: StubURLProtocol.makeSession(),
            apiKeyProvider: { "voice-test-key" }
        )
        let transcriber = GeminiVoiceTranscriber(api: api)
        let bytes = Data([0x52, 0x49, 0x46, 0x46])

        let transcript = try await transcriber.transcribe(
            VoiceAudio(data: bytes, mimeType: "audio/wav", duration: 1.25)
        )

        #expect(transcript == "Привет, world!")
        let request = try #require(StubURLProtocol.requestedRequests.first)
        #expect(request.url?.path == "/v1beta/models/gemini-3.7-flash:generateContent")
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "voice-test-key")
        #expect(request.timeoutInterval == 120)

        let bodyData = try #require(StubURLProtocol.requestedHTTPBodies.first)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let contents = try #require(body["contents"] as? [[String: Any]])
        let parts = try #require(contents.first?["parts"] as? [[String: Any]])
        #expect(parts.first?["text"] as? String == VoiceTranscriptionPolicy.instruction)
        let inlineData = try #require(parts.last?["inline_data"] as? [String: Any])
        #expect(inlineData["mime_type"] as? String == "audio/wav")
        #expect(inlineData["data"] as? String == bytes.base64EncodedString())
        let generationConfig = try #require(body["generationConfig"] as? [String: Any])
        #expect(generationConfig["responseModalities"] as? [String] == ["TEXT"])
    }

    @Test func rejectsEmptyAudioBeforeReadingCredentialsOrSending() async {
        StubURLProtocol.reset()
        var credentialReads = 0
        let api = GeminiAPI(
            session: StubURLProtocol.makeSession(),
            apiKeyProvider: {
                credentialReads += 1
                return "unused"
            }
        )
        let transcriber = GeminiVoiceTranscriber(api: api)

        await #expect(throws: VoiceTranscriptionError.emptyAudio) {
            _ = try await transcriber.transcribe(
                VoiceAudio(data: Data(), mimeType: "audio/wav", duration: 1)
            )
        }
        #expect(credentialReads == 0)
        #expect(StubURLProtocol.requestedURLs.isEmpty)
    }

    @Test func rejectsAudioThatWouldExceedInlineRequestLimit() async {
        StubURLProtocol.reset()
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "unused" })
        let transcriber = GeminiVoiceTranscriber(api: api)
        let bytes = Data(
            repeating: 0,
            count: VoiceTranscriptionPolicy.maximumInlineAudioBytes + 1
        )

        await #expect(
            throws: VoiceTranscriptionError.audioTooLarge(
                maximumBytes: VoiceTranscriptionPolicy.maximumInlineAudioBytes
            )
        ) {
            _ = try await transcriber.transcribe(
                VoiceAudio(data: bytes, mimeType: "audio/wav", duration: 60)
            )
        }
        #expect(StubURLProtocol.requestedURLs.isEmpty)
    }

    @Test(arguments: ["text/plain", "audio/", "audio/wav; charset=utf-8"])
    func rejectsInvalidAudioMIMEType(_ mimeType: String) async {
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "unused" })
        let transcriber = GeminiVoiceTranscriber(api: api)

        await #expect(throws: VoiceTranscriptionError.invalidMIMEType(mimeType)) {
            _ = try await transcriber.transcribe(
                VoiceAudio(data: Data([1]), mimeType: mimeType, duration: 1)
            )
        }
    }

    @Test(arguments: [0, -1, .infinity, .nan])
    func rejectsInvalidDuration(_ duration: TimeInterval) async {
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "unused" })
        let transcriber = GeminiVoiceTranscriber(api: api)

        await #expect(throws: VoiceTranscriptionError.invalidDuration) {
            _ = try await transcriber.transcribe(
                VoiceAudio(data: Data([1]), mimeType: "audio/wav", duration: duration)
            )
        }
    }

    @Test func rejectsWhitespaceOnlyTranscript() async {
        StubURLProtocol.reset()
        StubURLProtocol.queue = [
            .init(
                statusCode: 200,
                data: #"{"candidates":[{"content":{"parts":[{"text":"  \n"}]}}]}"#.data(using: .utf8)!
            )
        ]
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })
        let transcriber = GeminiVoiceTranscriber(api: api)

        await #expect(throws: VoiceTranscriptionError.emptyTranscript) {
            _ = try await transcriber.transcribe(
                VoiceAudio(data: Data([1]), mimeType: "audio/wav", duration: 1)
            )
        }
    }

    @Test func preservesServerErrors() async {
        StubURLProtocol.reset()
        StubURLProtocol.queue = [
            .init(
                statusCode: 429,
                data: #"{"error":{"message":"Quota exhausted"}}"#.data(using: .utf8)!
            )
        ]
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })
        let transcriber = GeminiVoiceTranscriber(api: api)

        do {
            _ = try await transcriber.transcribe(
                VoiceAudio(data: Data([1]), mimeType: "audio/wav", duration: 1)
            )
            Issue.record("Expected Gemini server error")
        } catch let error as GeminiAPI.APIError {
            #expect(error.localizedDescription.contains("429"))
            #expect(error.localizedDescription.contains("Quota exhausted"))
        } catch {
            Issue.record("Expected the original GeminiAPI error, got \(error)")
        }
    }

    @Test func preservesTransportCancellation() async throws {
        PendingVoiceURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PendingVoiceURLProtocol.self]
        let api = GeminiAPI(
            session: URLSession(configuration: configuration),
            apiKeyProvider: { "test-key" }
        )
        let transcriber = GeminiVoiceTranscriber(api: api)
        let task = Task {
            try await transcriber.transcribe(
                VoiceAudio(data: Data([1]), mimeType: "audio/wav", duration: 1)
            )
        }

        // Let URLSession enter the stub before cancelling so this exercises the
        // in-flight upload path rather than cancellation before task execution.
        for _ in 0..<1_000 where !PendingVoiceURLProtocol.didStart {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(PendingVoiceURLProtocol.didStart)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected the transcription request to be cancelled")
        } catch is CancellationError {
            // Native Swift cancellation is intentionally preserved.
        } catch let error as URLError {
            // Foundation represents URLSession cancellation this way on some OS
            // versions; it is still the original transport cancellation.
            #expect(error.code == .cancelled)
        } catch {
            Issue.record("Expected an unwrapped cancellation error, got \(error)")
        }
        for _ in 0..<1_000 where !PendingVoiceURLProtocol.didStop {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(PendingVoiceURLProtocol.didStop)
    }
}

/// A request that only completes when URLSession cancels it. Static state is
/// acceptable here because the containing suite is serialized.
private final class PendingVoiceURLProtocol: URLProtocol {
    nonisolated(unsafe) static var didStart = false
    nonisolated(unsafe) static var didStop = false

    static func reset() {
        didStart = false
        didStop = false
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.didStart = true
    }

    override func stopLoading() {
        Self.didStop = true
    }
}
