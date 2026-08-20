import Testing
@testable import fixer

struct MicrophoneAuthorizationPolicyTests {
    @Test func authorizedInputCanProceedWithoutAPrompt() throws {
        let decision = try MicrophoneAuthorizationPolicy.decision(for: .authorized)
        #expect(decision == .proceed)
    }

    @Test func undeterminedInputRequestsPermission() throws {
        let decision = try MicrophoneAuthorizationPolicy.decision(for: .notDetermined)
        #expect(decision == .requestPermission)
    }

    @Test func deniedAndRestrictedHaveDifferentUserFacingErrors() {
        #expect(throws: VoiceCaptureError.microphonePermissionDenied) {
            try MicrophoneAuthorizationPolicy.decision(for: .denied)
        }
        #expect(throws: VoiceCaptureError.microphonePermissionRestricted) {
            try MicrophoneAuthorizationPolicy.decision(for: .restricted)
        }
        #expect(
            VoiceCaptureError.microphonePermissionDenied.errorDescription?
                .contains("System Settings") == true
        )
        #expect(
            VoiceCaptureError.microphonePermissionRestricted.errorDescription?
                .contains("restricted") == true
        )
    }
}
