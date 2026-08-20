import Foundation

/// A provider-neutral recording passed from the microphone layer to a
/// transcription service.
///
/// The transport owns no file URL: callers can erase their temporary recording
/// as soon as its bytes have been loaded into this value.
struct VoiceAudio: Sendable, Equatable {
    let data: Data
    let mimeType: String
    let duration: TimeInterval
}
