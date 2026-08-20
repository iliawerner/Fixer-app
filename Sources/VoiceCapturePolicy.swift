import Foundation

enum VoiceCapturePolicy {
    /// Prevents an accidentally left-open microphone and bounds memory/upload size.
    static let maximumDuration: TimeInterval = 5 * 60
    /// 16 kHz mono PCM preserves speech detail while keeping five minutes below
    /// Gemini's inline-request size limit.
    static let outputSampleRate = 16_000
    static let mimeType = "audio/wav"
}
