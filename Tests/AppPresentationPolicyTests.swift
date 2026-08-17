import AppKit
import Testing
@testable import fixer

struct AppPresentationPolicyTests {
    @Test func blocksActivatingWindowsWhileAnActionIsRunning() {
        #expect(!AppPresentationPolicy.mayActivateFixer(isProcessing: true))
    }

    @Test func permitsActivatingWindowsWhenFixerIsIdle() {
        #expect(AppPresentationPolicy.mayActivateFixer(isProcessing: false))
    }

    @Test @MainActor
    func processingReopenEventDoesNotContinueIntoAppKitDefaultHandling() {
        let previous = AppState.shared.isProcessing
        AppState.shared.isProcessing = true
        defer { AppState.shared.isProcessing = previous }

        let delegate = AppDelegate()
        let shouldContinue = delegate.applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false
        )

        #expect(!shouldContinue)
    }
}
