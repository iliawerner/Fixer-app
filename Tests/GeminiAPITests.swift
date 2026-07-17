import Testing
import Foundation
@testable import fixer

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
        #expect(GeminiAPI.isValidModelID("models/gemini-2.5-flash"))
    }

    @Test(arguments: ["models/gemini 2.5", "", "models/x:y", "models/x\ny"])
    func rejectsUnsafeModelIDs(_ id: String) {
        #expect(!GeminiAPI.isValidModelID(id))
    }

    // MARK: fetchModels (stubbed transport)

    @Test func stitchesPagesFiltersAndStopsOnEmptyToken() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.queue = [
            .init(statusCode: 200, data: #"{"models":[{"name":"models/a","displayName":"A","supportedGenerationMethods":["generateContent"]}],"nextPageToken":"p2"}"#.data(using: .utf8)!),
            // second page: b is filtered out (no generateContent), c has nil displayName,
            // and an empty-string nextPageToken must terminate the loop (bug regression).
            .init(statusCode: 200, data: #"{"models":[{"name":"models/b","supportedGenerationMethods":["embedContent"]},{"name":"models/c","supportedGenerationMethods":["generateContent"]}],"nextPageToken":""}"#.data(using: .utf8)!)
        ]

        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })
        let models = try await api.fetchModels()

        #expect(models.map(\.name) == ["models/a", "models/c"])
        #expect(models[0].displayName == "A")
        #expect(models[1].displayName == "models/c")          // nil displayName falls back to name
        #expect(StubURLProtocol.requestedURLs.count == 2)     // stopped after the empty token
    }

    @Test func missingKeyThrows() async {
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { nil })
        await #expect(throws: GeminiAPI.APIError.self) { try await api.fetchModels() }
    }

    @Test func invalidModelIsRejectedBeforeNetwork() async {
        let api = GeminiAPI(session: StubURLProtocol.makeSession(), apiKeyProvider: { "test-key" })
        await #expect(throws: GeminiAPI.APIError.self) {
            _ = try await api.generateContent(model: "bad model", prompt: "hi")
        }
    }
}
