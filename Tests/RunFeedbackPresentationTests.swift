import Testing
@testable import fixer

struct RunFeedbackPresentationTests {
    @Test func workingStateNamesTheActionAndDoesNotAutoHide() {
        let value = RunFeedbackPresentation.working(actionName: "Fix Grammar")

        #expect(value.phase == .working)
        #expect(value.label == "FIXING")
        #expect(value.title == "Fix Grammar")
        #expect(value.detail == "Gemini is working · up to 30 sec")
        #expect(value.dismissAfter == nil)
    }

    @Test func repeatedTriggerReportsTheRunAlreadyInProgress() {
        let value = RunFeedbackPresentation.busy(actionName: "Fix Grammar")

        #expect(value.phase == .busy)
        #expect(value.label == "STILL FIXING")
        #expect(value.title == "Fix Grammar")
        #expect(value.detail == "Already running · wait for the result")
        #expect(value.dismissAfter == 1.4)
    }

    @Test func successUsesHonestPasteCopyAndAQuickDismissal() {
        let value = RunFeedbackPresentation.success(actionName: "Fix Grammar", mode: .replace)

        #expect(value.phase == .success)
        #expect(value.label == "RESULT SENT")
        #expect(value.title == "Fix Grammar")
        #expect(value.detail == "Replace · ⌘Z undoes in the active app")
        #expect(value.dismissAfter == 1.6)
    }

    @Test func appendSuccessNamesItsOutputMode() {
        let value = RunFeedbackPresentation.success(actionName: "Draft Reply", mode: .append)
        #expect(value.detail == "Append · ⌘Z undoes in the active app")
    }

    @Test func errorKeepsTheProviderMessageReadable() {
        let value = RunFeedbackPresentation.error("API quota exceeded")

        #expect(value.phase == .error)
        #expect(value.label == "NEEDS ATTENTION")
        #expect(value.title == "Couldn’t finish")
        #expect(value.detail == "API quota exceeded")
        #expect(value.dismissAfter == 5.5)
    }
}
