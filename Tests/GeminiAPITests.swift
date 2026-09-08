import Testing
import Foundation
@testable import fixer

@Suite(.serialized)
struct GeminiAPITests {

    // MARK: parseGenerateResponse

    @Test func parsesMultiPartCandidate() throws {
        let json = #"{"candidates":[{"content":{"parts":[{"text":"Hello "},{"text":"world"}]}}]}"#.data(using: .utf8)!
        #expect(try GeminiAPI.parseGenerateResponse(json) == "Hello world")
    }

    @Test func blockedByPromptFeedbackThrows() {
        let json = #"{"promptFeedback":{"blockReason":"SAFETY"}}"#.data(using: .utf8)!
        #expect(throws: GeminiAPI.APIError.self) { try GeminiAPI.parseGenerateResponse(json) }
    }

    @Test func emptyCandidateWithFinishReasonThrows() {
        let json = #"{"candidates":[{"content":{"parts":[]},"finishReason":"MAX_TOKENS"}]}"#.data(using: .utf8)!
        #expect(throws: GeminiAPI.APIError.self) { try GeminiAPI.parseGenerateResponse(json) }
    }

    @Test func noCandidatesThrowsInvalidResponse() {
        #expect(throws: GeminiAPI.APIError.self) { try GeminiAPI.parseGenerateResponse("{}".data(using: .utf8)!) }
    }

    // MARK: extractMessage

    @Test(arguments: ["MAX_TOKENS", "SAFETY", "RECITATION", "OTHER"])
    func nonemptyAbnormalCompletionPreservesPartialWithoutAcceptingIt(_ reason: String) throws {
        let data = Data("{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"partial\"}]},\"finishReason\":\"\(reason)\"}]}".utf8)
        do {
            _ = try GeminiAPI.parseGenerateResponse(data)
            Issue.record("Partial output must not be treated as successful")
        } catch GeminiAPI.APIError.incompleteResponse(let partial) {
            #expect(partial == "partial")
        }
    }

    @Test func normalCompletionIsAccepted() throws {
        let data = Data(#"{"candidates":[{"content":{"parts":[{"text":"complete"}]},"finishReason":"STOP"}]}"#.utf8)
        #expect(try GeminiAPI.parseGenerateResponse(data) == "complete")
    }

    @Test func extractsGoogleErrorMessage() {
        let raw = #"{"error":{"message":"API key not valid","code":400}}"#
        #expect(GeminiAPI.extractMessage(from: raw) == "API key not valid")
    }

    @Test func fallsBackToRawTextWhenNotErrorJSON() {
        let raw = "<html>Bad Gateway</html>"
        #expect(GeminiAPI.extractMessage(from: raw) == raw)
    }

    // MARK: isValidModelID

    @Test func acceptsWellFormedModelID() {
        #expect(GeminiAPI.isValidModelID("models/gemini-3.6-flash"))
    }

    @Test(arguments: ["models/gemini 2.5", "", "models/x:y", "models/x\ny"])
    func rejectsUnsafeModelIDs(_ id: String) {
        #expect(!GeminiAPI.isValidModelID(id))
    }

    @Test(arguments: [
        "models/gemini-2.5-flash-image",
        "models/gemini-2.5-pro-preview-tts",
        "models/gemini-2.0-flash-live-001",
        "models/veo-3.1-generate-preview",
        "models/lyria-realtime-exp"
    ])
    func rejectsNonTextCatalogModels(_ id: String) {
        #expect(!GeminiAPI.isCatalogTextModel(id))
    }

    @Test(arguments: [
        "models/gemini-2.5-flash",
        "models/gemini-3.1-pro-preview",
        "models/gemma-3-27b-it"
    ])
    func acceptsTextCatalogModels(_ id: String) {
        #expect(GeminiAPI.isCatalogTextModel(id))
    }

    // MARK: fetchModels (stubbed transport)

    @Test func stitchesPagesFiltersAndStopsOnEmptyToken() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.queue = [
            .init(statusCode: 200, data: #"{"models":[{"name":"models/gemini-a","displayName":"A","supportedGenerationMethods":["generateContent"]}],"nextPageToken":"p2"}"#.data(using: .utf8)!),
            // second page: b is filtered out (no generateContent), c has nil displayName,
            // and an empty-string nextPageToken must terminate the loop (bug regression).
            .init(statusCode: 200, data: #"{"models":[{"name":"models/gemini-b","supportedGenerationMethods":["embedContent"]},{"name":"models/gemini-c","supportedGenerationMethods":["generateContent"]},{"name":"models/gemini-c-image","supportedGenerationMethods":["generateContent"]}],"nextPageToken":""}"#.data(using: .utf8)!)
        ]

        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })
        let models = try await api.fetchModels()

        #expect(models.map(\.name) == ["models/gemini-a", "models/gemini-c"])
        #expect(models[0].displayName == "A")
        #expect(models[1].displayName == "models/gemini-c")   // nil displayName falls back to name
        #expect(StubURLProtocol.requestedURLs.count == 2)     // stopped after the empty token
    }

    @Test func generationExplicitlyRequestsTextOutput() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.queue = [
            .init(
                statusCode: 200,
                data: #"{"candidates":[{"content":{"parts":[{"text":"fixed"}]}}]}"#.data(using: .utf8)!
            )
        ]
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })

        let result = try await api.generateContent(
            model: "models/gemini-3.6-flash",
            prompt: "Fix this"
        )

        #expect(result == "fixed")
        let body = try #require(StubURLProtocol.requestedHTTPBodies.first)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let generationConfig = try #require(object["generationConfig"] as? [String: Any])
        #expect(generationConfig["responseModalities"] as? [String] == ["TEXT"])
    }

    @Test func missingKeyThrows() async {
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { nil })
        await #expect(throws: GeminiAPI.APIError.self) { try await api.fetchModels() }
    }

    @Test func keychainReadFailureIsReportedBeforeNetwork() async {
        StubURLProtocol.reset()
        let api = GeminiAPI(
            session: StubURLProtocol.makeSession(),
            apiKeyProvider: { throw TestKeyReadFailure.denied }
        )

        do {
            _ = try await api.fetchModels()
            Issue.record("Expected Keychain read failure")
        } catch {
            #expect(error.localizedDescription.contains("couldn't read"))
            #expect(error.localizedDescription.contains("Keychain"))
        }
        #expect(StubURLProtocol.requestedURLs.isEmpty)
    }

    @Test func invalidModelIsRejectedBeforeNetwork() async {
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })
        await #expect(throws: GeminiAPI.APIError.self) {
            _ = try await api.generateContent(model: "bad model", prompt: "hi")
        }
    }
}

private enum TestKeyReadFailure: LocalizedError {
    case denied

    var errorDescription: String? { "Keychain access denied" }
}
