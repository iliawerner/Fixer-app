import Foundation
import KeyboardShortcuts

// MARK: - Output

/// Determines how generated text is combined with the user's selection.
///
/// The raw values are persisted inside `MacroAction`; changing them requires a
/// data migration rather than a display-copy edit.
enum ActionOutputMode: String, Codable, CaseIterable, Identifiable {
    case replace = "Replace"
    case append = "Append"

    var id: String { self.rawValue }
}

// MARK: - Action identity and voice behavior

/// Distinguishes user-authored transformations from Fixer's permanent voice
/// entry point. The value is persisted so future migrations never have to infer
/// identity from user-visible copy such as the Action name.
enum ActionKind: String, Codable {
    case text
    case dictation
}

/// Determines how a voice shortcut ends recording.
///
/// This setting lives on the built-in Dictation Action and applies to every
/// voice-enabled Action. Keeping one global gesture avoids the surprising case
/// where identical shortcuts behave differently depending on the selected row.
enum VoiceActivationMode: String, Codable, CaseIterable, Identifiable {
    case toggle
    case hold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggle: "Press again"
        case .hold: "Hold"
        }
    }
}

// MARK: - Provider model

/// A Gemini catalog entry displayed by the action editor.
struct GeminiModel: Codable, Identifiable, Hashable {
    /// Full resource name as returned by the API, already prefixed with "models/"
    /// (e.g. "models/gemini-3.6-flash"). This is the value passed straight to
    /// generateContent — the "models/" prefix must appear exactly once.
    let name: String
    let displayName: String

    var id: String { name }
}

/// A single default model that is broadly available on the Gemini API. Carries
/// exactly one "models/" prefix so it can be used directly as a request path.
let defaultModelName = "models/gemini-3.6-flash"

// MARK: - Saved action

/// A user-defined text transformation persisted by `SettingsManager`.
///
/// `shortcutName` is both persisted data and the stable identity used by the
/// KeyboardShortcuts package. Copies and newly created actions must receive a
/// fresh shortcut name even when every other field is duplicated.
struct MacroAction: Codable, Identifiable {
    /// Stable identity of the permanent Action. Its editable voice settings are
    /// persisted, while `SettingsManager` repairs its protected fields on load.
    static let dictationID = UUID(uuidString: "D1C7A710-0000-4000-8000-000000000001")!
    static let dictationShortcutName = KeyboardShortcuts.Name("builtInDictationAction")

    var id: UUID = UUID()
    var kind: ActionKind = .text
    var name: String = "New action"
    var shortcutName: KeyboardShortcuts.Name
    var promptTemplate: String = "Fix grammar and phrasing: {text}"
    var modelName: String = defaultModelName
    var outputMode: ActionOutputMode = .replace
    var isEnabled: Bool = true
    var voiceActivationMode: VoiceActivationMode = .toggle

    init(id: UUID = UUID(),
         kind: ActionKind = .text,
         name: String = "New action",
         shortcutName: KeyboardShortcuts.Name,
         promptTemplate: String = "Fix grammar and phrasing: {text}",
         modelName: String = defaultModelName,
         outputMode: ActionOutputMode = .replace,
         isEnabled: Bool = true,
         voiceActivationMode: VoiceActivationMode = .toggle) {
        self.id = id
        self.kind = kind
        self.name = name
        self.shortcutName = shortcutName
        self.promptTemplate = promptTemplate
        self.modelName = modelName
        self.outputMode = outputMode
        self.isEnabled = isEnabled
        self.voiceActivationMode = voiceActivationMode
    }

    /// A canonical built-in value. `SettingsManager` preserves only its enabled
    /// state and activation gesture when normalizing a persisted snapshot.
    static func dictation(
        isEnabled: Bool = true,
        activationMode: VoiceActivationMode = .toggle
    ) -> MacroAction {
        MacroAction(
            id: dictationID,
            kind: .dictation,
            name: "Dictation",
            shortcutName: dictationShortcutName,
            promptTemplate: "",
            modelName: defaultModelName,
            outputMode: .replace,
            isEnabled: isEnabled,
            voiceActivationMode: activationMode
        )
    }

    /// True only for shortcuts that must open the recording flow.
    var usesVoiceInput: Bool {
        kind == .dictation || promptTemplate.contains("{voice}")
    }

    // MARK: - Codable compatibility

    enum CodingKeys: String, CodingKey {
        case id, kind, name, shortcutName, promptTemplate, modelName, outputMode,
             isEnabled, voiceActivationMode
    }

    /// Decodes each field independently so one malformed or missing value cannot
    /// fail the complete `[MacroAction]` array and cause the store to reseed.
    ///
    /// The hand-written conformance also persists `KeyboardShortcuts.Name`
    /// through its raw string. It is a compatibility boundary, not redundant
    /// boilerplate.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A missing key and a present-but-invalid value both use the field's
        // fallback, preserving all other valid fields in the saved action.
        func opt<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? container.decodeIfPresent(type, forKey: key)) ?? nil
        }
        id = opt(UUID.self, .id) ?? UUID()
        kind = opt(ActionKind.self, .kind) ?? .text
        name = opt(String.self, .name) ?? "New action"
        if let nameString = opt(String.self, .shortcutName) {
            shortcutName = KeyboardShortcuts.Name(nameString)
        } else {
            shortcutName = KeyboardShortcuts.Name(UUID().uuidString)
        }
        promptTemplate = opt(String.self, .promptTemplate) ?? "Fix grammar and phrasing: {text}"
        modelName = opt(String.self, .modelName) ?? defaultModelName
        outputMode = opt(ActionOutputMode.self, .outputMode) ?? .replace
        isEnabled = opt(Bool.self, .isEnabled) ?? true
        voiceActivationMode = opt(VoiceActivationMode.self, .voiceActivationMode) ?? .toggle
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(shortcutName.rawValue, forKey: .shortcutName)
        try container.encode(promptTemplate, forKey: .promptTemplate)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(outputMode, forKey: .outputMode)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(voiceActivationMode, forKey: .voiceActivationMode)
    }
}
