/// Boundary around macOS microphone authorization.
protocol MicrophoneAuthorizing: Sendable {
    func authorizationStatus() -> MicrophoneAuthorizationStatus
    func requestAuthorization() async -> Bool
}
