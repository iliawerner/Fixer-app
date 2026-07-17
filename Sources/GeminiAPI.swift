import Foundation

/// Stateless client for the Gemini REST API. `@unchecked Sendable` is sound only
/// because this type holds no mutable stored state (the key is fetched fresh from
/// the Keychain per call); if you add a stored `var`, add real synchronization or
/// it becomes a data race.
final class GeminiAPI: @unchecked Sendable {
    static let shared = GeminiAPI()

    private let session: URLSession
    private let apiKeyProvider: () -> String?

    /// - Parameters:
    ///   - session: transport to use. Injectable so tests can drive it with a stub
    ///     `URLProtocol` instead of hitting the network.
    ///   - apiKeyProvider: supplies the API key per request. Defaults to the
    ///     Keychain; injectable so tests don't touch the real Keychain.
    init(session: URLSession = .shared,
         apiKeyProvider: @escaping () -> String? = { KeychainManager.shared.getAPIKey() }) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    enum APIError: LocalizedError {
        case missingAPIKey
        case invalidModel(String)
        case invalidResponse
        case blocked(String)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "No Gemini API key set. Open Settings and paste your key."
            case .invalidModel(let model):
                return "Invalid model id: \"\(model)\"."
            case .invalidResponse:
                return "The Gemini response could not be read."
            case .blocked(let reason):
                return "Gemini returned no text (\(reason))."
            case .serverError(let message):
                return message
            }
        }
    }

    private var apiKey: String? {
        apiKeyProvider()
    }

    private let base = "https://generativelanguage.googleapis.com/v1beta"

    // MARK: - Models

    func fetchModels() async throws -> [GeminiModel] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

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
            .filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
            .map { GeminiModel(name: $0.name, displayName: $0.displayName ?? $0.name) }
    }

    // MARK: - Generation

    func generateContent(model: String, prompt: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
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
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data)
        return try Self.parseGenerateResponse(data)
    }

    // MARK: - Pure helpers (no I/O — unit tested directly)

    /// The model id is interpolated into the URL path unencoded, so reject spaces
    /// and other unsafe characters (e.g. a typo in the free-text field) instead of
    /// producing a malformed request.
    static func isValidModelID(_ model: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/.-_")
        return !model.isEmpty && model.rangeOfCharacter(from: allowed.inverted) == nil
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
