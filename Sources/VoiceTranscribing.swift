import Foundation

/// Converts recorded speech into plain text without exposing a provider to the
/// action runner. A future local engine can conform without changing that flow.
protocol VoiceTranscribing: Sendable {
    func transcribe(_ audio: VoiceAudio) async throws -> String
}

/// Provider-independent validation failures that the voice UI can explain
/// without parsing an HTTP error.
enum VoiceTranscriptionError: LocalizedError, Equatable {
    case emptyAudio
    case audioTooLarge(maximumBytes: Int)
    case invalidMIMEType(String)
    case invalidDuration
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return "No speech was recorded. Try again and speak after listening starts."
        case .audioTooLarge:
            return "The recording is too large to send to Gemini. Record a shorter message."
        case .invalidMIMEType(let mimeType):
            return "The recording uses an unsupported audio type: \(mimeType)."
        case .invalidDuration:
            return "The recording duration could not be read. Try recording again."
        case .emptyTranscript:
            return "Gemini did not detect any speech in the recording."
        }
    }
}
