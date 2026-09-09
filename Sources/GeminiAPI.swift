import Foundation

/// Stateless transport boundary for the Gemini REST API.
///
/// The API key is fetched for every operation and sent in the `x-goog-api-key`
/// header, never in the URL. `@unchecked Sendable` shifts responsibility to the
/// injected session and credential closure: their captured state must be safe for
/// concurrent use, and this type must not gain unsynchronized mutable state.
final class GeminiAPI: @unchecked Sendable {
    // MARK: - Shared client and dependencies

    static let shared = GeminiAPI()

    private let session: URLSession
    private let apiKeyProvider: () throws -> String?

    /// Creates a client with injectable credential and transport boundaries.
    ///
    /// - Parameters:
    ///   - session: transport to use. Injectable so tests can drive it with a stub
    ///     `URLProtocol` instead of hitting the network.
    ///   - apiKeyProvider: supplies the API key per request. Defaults to the
    ///     Keychain; injectable so tests don't touch the real Keychain.
    init(session: URLSession = .shared,
         apiKeyProvider: @escaping () throws -> String? = { try KeychainManager.shared.getAPIKey() }) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    // MARK: - Errors

    /// Errors translated into copy suitable for the run HUD and menu.
    enum APIError: LocalizedError {
        case missingAPIKey
        case keychainUnavailable(String)
        case invalidModel(String)
        case invalidResponse
        case incompleteResponse(String)
        case blocked(String)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "No Gemini API key set. Open Settings and paste your key."
            case .keychainUnavailable(let message):
                return "Fixer couldn't read the Gemini API key from Keychain: \(message)"
            case .invalidModel(let model):
                return "Invalid model id: \"\(model)\"."
            case .invalidResponse:
                return "The Gemini response could not be read."
            case .incompleteResponse:
                return "Gemini returned an incomplete response. The partial result is available in History."
            case .blocked(let reason):
                return "Gemini returned no text (\(reason))."
            case .serverError(let message):
                return message
            }
        }
    }

    // MARK: - Authentication

    private func requiredAPIKey() throws -> String {
        do {
            guard let apiKey = try apiKeyProvider(), !apiKey.isEmpty else {
                throw APIError.missingAPIKey
            }
            return apiKey
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.keychainUnavailable(error.localizedDescription)
        }
    }

    /// Versioned API root. Authentication is deliberately not encoded here.
    private let base = "https://generativelanguage.googleapis.com/v1beta"

    // MARK: - Models

    /// Fetches paginated catalog entries that can serve Fixer's text-only flow.
    ///
    /// Google's model-list payload exposes API methods but not supported output
    /// modality combinations. The catalog therefore uses a conservative family
    /// filter in addition to `generateContent`; an exact custom id remains
    /// available in the editor for future text models the catalog cannot classify.
    func fetchModels() async throws -> [GeminiModel] {
        let apiKey = try requiredAPIKey()

        struct ModelData: Decodable {
            let name: String
            let displayName: String?
            let supportedGenerationMethods: [String]?
        }
        struct ModelsResponse: Decodable {
            let models: [ModelData]?
            let nextPageToken: String?
        }

        var collected: [ModelData] = []
        var pageToken: String? = nil
        var pagesFetched = 0
        let maxPages = 20 // safety cap: a misbehaving server must never hang the refresh forever

        // Follow pagination so accounts with large catalogs don't get a truncated
        // list (which would hide the desired model from the picker entirely).
        repeat {
            var components = URLComponents(string: "\(base)/models")!
            var query = [URLQueryItem(name: "pageSize", value: "200")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            guard let url = components.url else { throw APIError.serverError("Could not build models URL.") }

            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

            let (data, response) = try await session.data(for: request)
            try Self.validate(response, data)

            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            collected.append(contentsOf: decoded.models ?? [])
            pagesFetched += 1
            // Stop on a nil OR empty-string token: some Google APIs return "" for
            // the last page instead of omitting the field, and "" != nil would
            // otherwise loop forever.
            let next = decoded.nextPageToken
            pageToken = (next?.isEmpty == false) ? next : nil
        } while pageToken != nil && pagesFetched < maxPages

        return collected
            .filter {
                $0.supportedGenerationMethods?.contains("generateContent") == true
                    && Self.isCatalogTextModel($0.name)
            }
            .map { GeminiModel(name: $0.name, displayName: $0.displayName ?? $0.name) }
    }

    // MARK: - Generation

    /// Sends a text prompt to the selected model and returns the first
    /// candidate's concatenated textual parts.
    func generateContent(model: String, prompt: String) async throws -> String {
        let apiKey = try requiredAPIKey()
        guard Self.isValidModelID(model) else {
            throw APIError.invalidModel(model)
        }
        guard let url = URL(string: "\(base)/\(model):generateContent") else {
            throw APIError.invalidModel(model)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            // Fixer can only insert text. Requesting that modality explicitly is
            // fail-closed for a manually entered image/audio model: Gemini returns
            // an API error instead of producing binary parts Fixer cannot deliver.
            "generationConfig": ["responseModalities": ["TEXT"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data)
        return try Self.parseGenerateResponse(data)
    }

    /// Sends recorded audio and the app-owned transcription instruction in one
    /// inline request. Validation of size, duration, and MIME shape stays in the
    /// provider-neutral transcriber so alternate engines share the same contract.
    func transcribeAudio(model: String,
                         instruction: String,
                         audio: VoiceAudio) async throws -> String {
        let apiKey = try requiredAPIKey()
        guard Self.isValidModelID(model) else {
            throw APIError.invalidModel(model)
        }
        guard let url = URL(string: "\(base)/\(model):generateContent") else {
            throw APIError.invalidModel(model)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Transcription can outlive the text-only request for a long recording,
        // while still remaining bounded for a stalled or disconnected upload.
        request.timeoutInterval = 120
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": instruction],
                        [
                            "inline_data": [
                                "mime_type": audio.mimeType,
                                "data": audio.data.base64EncodedString()
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": ["responseModalities": ["TEXT"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Do not translate cancellation into an APIError: the caller uses task
        // cancellation to guarantee that Cancel never becomes a late upload/UI
        // success. URLSession propagates its cancellation error unchanged here.
        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data)
        return try Self.parseGenerateResponse(data)
    }

    // MARK: - Response parsing and validation

    /// The model id is interpolated into the URL path unencoded, so reject spaces
    /// and other unsafe characters (e.g. a typo in the free-text field) instead of
    /// producing a malformed request.
    static func isValidModelID(_ model: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/.-_")
        return !model.isEmpty && model.rangeOfCharacter(from: allowed.inverted) == nil
    }

    /// Returns whether a catalog id belongs to a general text-generating family.
    /// Capability-specific Gemini variants are intentionally excluded because
    /// their `generateContent` support may produce image, audio, video, tool, or
    /// live-session output that the paste pipeline cannot represent.
    static func isCatalogTextModel(_ model: String) -> Bool {
        let id = model.lowercased()
        guard id.hasPrefix("models/gemini-") || id.hasPrefix("models/gemma-") else {
            return false
        }

        let unsupportedMarkers = [
            "image", "imagen", "tts", "audio", "lyria", "veo",
            "live", "robotics", "computer-use"
        ]
        return !unsupportedMarkers.contains(where: id.contains)
    }

    /// Parses a 200 `generateContent` body into the output text. Throws `.blocked`
    /// for a safety stop (block reason or an empty/finishReason-only candidate) and
    /// `.invalidResponse` when there are no candidates at all.
    static func parseGenerateResponse(_ data: Data) throws -> String {
        struct GenerateResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]?
                }
                let content: Content?
                let finishReason: String?
            }
            struct PromptFeedback: Decodable { let blockReason: String? }
            let candidates: [Candidate]?
            let promptFeedback: PromptFeedback?
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)

        // Safety block: HTTP 200 with no candidates but a blockReason.
        if let reason = decoded.promptFeedback?.blockReason,
           (decoded.candidates?.isEmpty ?? true) {
            throw APIError.blocked("blocked: \(reason)")
        }

        guard let candidate = decoded.candidates?.first else {
            throw APIError.invalidResponse
        }

        let text = candidate.content?.parts?.compactMap { $0.text }.joined() ?? ""
        if text.isEmpty {
            // A candidate with no text is usually a safety/recitation/length stop.
            let reason = candidate.finishReason ?? "no text returned"
            throw APIError.blocked(reason)
        }
        if let reason = candidate.finishReason, reason != "STOP" {
            throw APIError.incompleteResponse(text)
        }
        return text
    }

    private static func validate(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.serverError("HTTP \(http.statusCode): \(Self.extractMessage(from: raw))")
        }
    }

    /// Pulls the human-readable "message" out of a Google API error JSON body,
    /// falling back to the raw text (trimmed) so alerts stay readable.
    static func extractMessage(from raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(raw.prefix(300))
    }
}
