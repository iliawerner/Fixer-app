import Testing
@testable import fixer

struct AppPresentationPolicyTests {
    @Test func blocksActivatingWindowsWhileAnActionIsRunning() {
        #expect(!AppPresentationPolicy.mayActivateFixer(isProcessing: true))
    }

    @Test func permitsActivatingWindowsWhenFixerIsIdle() {
        #expect(AppPresentationPolicy.mayActivateFixer(isProcessing: false))
    }
}
