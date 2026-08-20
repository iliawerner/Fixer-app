import Foundation

/// A self-contained recording ready to cross the transcription boundary.
///
/// Capture deliberately returns bytes rather than a file URL: recordings stay
/// ephemeral, do not enter a user-visible history, and can be released as soon
/// as the network request completes.
struct CapturedVoiceAudio: Sendable, Equatable {
    let data: Data
    let mimeType: String
    let duration: TimeInterval
}
