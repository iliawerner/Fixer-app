import Foundation

/// Product-owned Gemini policy for speech recognition.
///
/// This is intentionally separate from an Action's selected text model: voice
/// Actions must keep recognizing speech when the user chooses a text-only model.
/// Gemini 3.7 Flash is the stable general-purpose audio model used by Google's
/// current inline-audio transcription examples, while retaining Flash latency.
enum VoiceTranscriptionPolicy {
    static let modelID = "models/gemini-3.7-flash"

    /// Inline request bodies must remain below Gemini's 20 MB total limit. Base64
    /// expands bytes by roughly one third, so 14 MiB leaves room for JSON and the
    /// fixed instruction instead of failing at the provider boundary.
    static let maximumInlineAudioBytes = 14 * 1_024 * 1_024

    static let instruction = """
        Transcribe the supplied audio exactly as spoken.
        Preserve every language and any language switching; do not translate.
        Add natural punctuation, but do not rewrite, summarize, or answer the speaker.
        Return only the transcript, with no label, markdown, or commentary.
        """
}

/// Gemini-first implementation of the provider-neutral transcription boundary.
struct GeminiVoiceTranscriber: VoiceTranscribing, Sendable {
    private let api: GeminiAPI

    init(api: GeminiAPI = .shared) {
        self.api = api
    }

    func transcribe(_ audio: VoiceAudio) async throws -> String {
        try Self.validate(audio)

        let response = try await api.transcribeAudio(
            model: VoiceTranscriptionPolicy.modelID,
            instruction: VoiceTranscriptionPolicy.instruction,
            audio: audio
        )
        let transcript = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw VoiceTranscriptionError.emptyTranscript
        }
        return transcript
    }

    private static func validate(_ audio: VoiceAudio) throws {
        guard !audio.data.isEmpty else {
            throw VoiceTranscriptionError.emptyAudio
        }
        guard audio.data.count <= VoiceTranscriptionPolicy.maximumInlineAudioBytes else {
            throw VoiceTranscriptionError.audioTooLarge(
                maximumBytes: VoiceTranscriptionPolicy.maximumInlineAudioBytes
            )
        }
        guard audio.duration.isFinite, audio.duration > 0 else {
            throw VoiceTranscriptionError.invalidDuration
        }

        // MIME values are JSON data rather than headers, but constraining their
        // shape catches recorder/configuration mistakes before audio is uploaded.
        let mimeType = audio.mimeType.lowercased()
        let allowedCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789!#$&^_.+-/"
        )
        guard mimeType.hasPrefix("audio/"),
              mimeType.count > "audio/".count,
              mimeType.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            throw VoiceTranscriptionError.invalidMIMEType(audio.mimeType)
        }
    }
}
