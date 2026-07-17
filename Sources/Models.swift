import Foundation
import KeyboardShortcuts

enum ActionOutputMode: String, Codable, CaseIterable, Identifiable {
    case replace = "Replace"
    case append = "Append"

    var id: String { self.rawValue }
}

struct GeminiModel: Codable, Identifiable, Hashable {
    /// Full resource name as returned by the API, already prefixed with "models/"
    /// (e.g. "models/gemini-2.5-flash"). This is the value passed straight to
    /// generateContent — the "models/" prefix must appear exactly once.
    let name: String
    let displayName: String

    var id: String { name }
}

/// A single default model that is broadly available on the Gemini API. Carries
/// exactly one "models/" prefix so it can be used directly as a request path.
let defaultModelName = "models/gemini-2.5-flash"

struct MacroAction: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "New action"
    var shortcutName: KeyboardShortcuts.Name
    var promptTemplate: String = "Fix grammar and phrasing: {text}"
    var modelName: String = defaultModelName
    var outputMode: ActionOutputMode = .replace
    var isEnabled: Bool = true

    init(id: UUID = UUID(),
         name: String = "New action",
         shortcutName: KeyboardShortcuts.Name,
         promptTemplate: String = "Fix grammar and phrasing: {text}",
         modelName: String = defaultModelName,
         outputMode: ActionOutputMode = .replace,
         isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.shortcutName = shortcutName
        self.promptTemplate = promptTemplate
        self.modelName = modelName
        self.outputMode = outputMode
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, name, shortcutName, promptTemplate, modelName, outputMode, isEnabled
    }

    // Tolerant decoding: any missing/renamed field falls back to its default
    // instead of throwing. Array decoding is all-or-nothing, so a single strict
    // failure here used to wipe every saved macro — decodeIfPresent prevents that.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New action"
        if let nameString = try container.decodeIfPresent(String.self, forKey: .shortcutName) {
            shortcutName = KeyboardShortcuts.Name(nameString)
        } else {
            shortcutName = KeyboardShortcuts.Name(UUID().uuidString)
        }
        promptTemplate = try container.decodeIfPresent(String.self, forKey: .promptTemplate) ?? "Fix grammar and phrasing: {text}"
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName) ?? defaultModelName
        outputMode = try container.decodeIfPresent(ActionOutputMode.self, forKey: .outputMode) ?? .replace
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(shortcutName.rawValue, forKey: .shortcutName)
        try container.encode(promptTemplate, forKey: .promptTemplate)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(outputMode, forKey: .outputMode)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}
