import Foundation

enum VoiceCaptureError: LocalizedError, Sendable, Equatable {
    case microphonePermissionDenied
    case microphonePermissionRestricted
    case noInputDevice
    case invalidInputFormat
    case alreadyRecording
    case notRecording
    case noAudioCaptured
    case couldNotStart(String)
    case couldNotEncode

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is off. Allow it in System Settings to use dictation."
        case .microphonePermissionRestricted:
            return "Microphone access is restricted on this Mac."
        case .noInputDevice:
            return "No microphone is available."
        case .invalidInputFormat:
            return "The microphone is using an unsupported audio format."
        case .alreadyRecording:
            return "A recording is already in progress."
        case .notRecording:
            return "No recording is in progress."
        case .noAudioCaptured:
            return "No speech was recorded."
        case .couldNotStart(let detail):
            return "Could not start the microphone. \(detail)"
        case .couldNotEncode:
            return "The recording could not be prepared for transcription."
        }
    }
}
