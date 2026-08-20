/// Pure permission decision used before touching the audio engine.
enum MicrophoneAuthorizationPolicy {
    enum Decision: Sendable, Equatable {
        case proceed
        case requestPermission
    }

    static func decision(for status: MicrophoneAuthorizationStatus) throws -> Decision {
        switch status {
        case .authorized:
            return .proceed
        case .notDetermined:
            return .requestPermission
        case .denied:
            throw VoiceCaptureError.microphonePermissionDenied
        case .restricted:
            throw VoiceCaptureError.microphonePermissionRestricted
        }
    }
}
