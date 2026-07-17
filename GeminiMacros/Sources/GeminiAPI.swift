import Foundation

final class GeminiAPI: @unchecked Sendable {
    static let shared = GeminiAPI()

    private init() {}

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
        KeychainManager.shared.getAPIKey()
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

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response, data)

            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            collected.append(contentsOf: decoded.models ?? [])
            pageToken = decoded.nextPageToken
        } while pageToken != nil

        return collected
            .filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
            .map { GeminiModel(name: $0.name, displayName: $0.displayName ?? $0.name) }
    }

    // MARK: - Generation

    func generateContent(model: String, prompt: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
        // Guard the model id: it is interpolated into the URL path unencoded, so
        // reject anything with spaces or other unsafe characters (e.g. a typo in
        // the free-text field) instead of producing a malformed request.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/.-_")
        guard !model.isEmpty, model.rangeOfCharacter(from: allowed.inverted) == nil else {
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

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data)

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

    // MARK: - Helpers

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
    private static func extractMessage(from raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(raw.prefix(300))
    }
}
