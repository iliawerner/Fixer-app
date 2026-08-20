enum VoiceAudioCaptureState: Sendable, Equatable {
    case idle
    case requestingPermission
    case recording
    case encoding
}
