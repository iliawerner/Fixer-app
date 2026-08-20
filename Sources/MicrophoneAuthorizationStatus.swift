/// App-owned permission states keep AVFoundation details out of the capture
/// coordinator and make denied/restricted behavior deterministic in tests.
enum MicrophoneAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}
