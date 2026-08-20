import Testing
@testable import fixer

struct RunFeedbackPresentationTests {
    @Test func workingStateNamesTheActionAndDoesNotAutoHide() {
        let value = RunFeedbackPresentation.working(actionName: "Fix Grammar")

        #expect(value.phase == .working)
        #expect(value.label == "Working")
        #expect(value.title == "Processing text…")
        #expect(value.detail == "Fix Grammar")
        #expect(!value.detail.contains(value.title))
        #expect(value.accessibilityAnnouncement == "Processing text… Fix Grammar")
        #expect(value.dismissAfter == nil)
        #expect(value.outputMode == nil)
    }

    @Test func repeatedTriggerReportsTheRunAlreadyInProgress() {
        let value = RunFeedbackPresentation.busy(actionName: "Fix Grammar")

        #expect(value.phase == .busy)
        #expect(value.label == "Working")
        #expect(value.title == "Already running")
        #expect(value.detail == "Fix Grammar")
        #expect(!value.detail.contains(value.title))
        #expect(value.accessibilityAnnouncement == "Already running. Fix Grammar")
        #expect(value.dismissAfter == 1.4)
        #expect(value.outputMode == nil)
    }

    @Test func successUsesHonestPasteCopyAndAQuickDismissal() {
        let value = RunFeedbackPresentation.success(actionName: "Fix Grammar", mode: .replace)

        #expect(value.phase == .success)
        #expect(value.label == "Complete")
        #expect(value.title == "Text replaced")
        #expect(value.detail.isEmpty)
        #expect(value.accessibilityAnnouncement == "Text replaced")
        #expect(value.dismissAfter == 1.6)
        #expect(value.outputMode == .replace)
    }

    @Test func appendSuccessNamesItsOutputMode() {
        let value = RunFeedbackPresentation.success(actionName: "Draft Reply", mode: .append)
        #expect(value.title == "Text appended")
        #expect(value.detail.isEmpty)
        #expect(value.outputMode == .append)
    }

    @Test func errorUsesTheProviderMessageAsADirectTitle() {
        let value = RunFeedbackPresentation.error("API quota exceeded")

        #expect(value.phase == .error)
        #expect(value.label == "Error")
        #expect(value.title == "API quota exceeded")
        #expect(value.detail == "Open the menu for details, then try again.")
        #expect(
            value.accessibilityAnnouncement
                == "API quota exceeded. Open the menu for details, then try again."
        )
        #expect(value.dismissAfter == 5.5)
        #expect(value.outputMode == nil)
    }

    @Test func voiceStagesUseLiteralStateCopyAndNoMetaphor() {
        let listening = RunFeedbackPresentation.listening(
            actionName: "Dictation",
            activationMode: .toggle
        )
        let transcribing = RunFeedbackPresentation.transcribingVoice()
        let cancelling = RunFeedbackPresentation.cancellingVoice()
        let applying = RunFeedbackPresentation.applyingVoice(actionName: "Draft reply")

        #expect(listening.phase == .listening)
        #expect(listening.title == "Listening…")
        #expect(listening.detail == "Dictation · Press again to stop")
        #expect(transcribing.title == "Transcribing…")
        #expect(cancelling.title == "Cancelling…")
        #expect(applying.title == "Applying action…")
        #expect(applying.detail == "Draft reply")
        #expect([listening, transcribing, cancelling, applying].allSatisfy {
            $0.dismissAfter == nil
        })
    }

    @Test func changedTargetAndCancelExplainExactlyWhatHappened() {
        let copied = RunFeedbackPresentation.copiedForChangedTarget()
        let cancelled = RunFeedbackPresentation.voiceCancelled()

        #expect(copied.phase == .notice)
        #expect(copied.title == "Copied — return and paste")
        #expect(cancelled.phase == .cancelled)
        #expect(cancelled.detail == "No audio was sent.")
    }

    @Test func repeatedBusyKeepsTheOriginalListeningRestoreTarget() throws {
        let listening = RunFeedbackPresentation.listening(
            actionName: "Dictation",
            activationMode: .hold
        )
        let busy = RunFeedbackPresentation.busy(actionName: "Dictation")

        let firstRestore = HUDBusyRestorePolicy.presentationToRestore(
            current: listening,
            previouslyStored: nil
        )
        let secondRestore = HUDBusyRestorePolicy.presentationToRestore(
            current: busy,
            previouslyStored: firstRestore
        )

        #expect(firstRestore == listening)
        #expect(secondRestore == listening)
    }
}
