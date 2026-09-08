import AppKit
import SwiftUI
import Testing
@testable import fixer

struct HistoryPresentationTests {
    @Test
    func retryRequiresRecoverableInputAndNeverEnablesForActiveRun() {
        var voice = HistoryEntry(action: .dictation(), status: .failed)
        #expect(!HistoryEntryPresentation.canRetry(voice, hasAudio: false))
        #expect(HistoryEntryPresentation.canRetry(voice, hasAudio: true))
        #expect(HistoryEntryPresentation.retryLabel(voice) == "Transcribe again")
        voice.transcript = "Recovered words"
        #expect(HistoryEntryPresentation.canRetry(voice, hasAudio: false))
        #expect(HistoryEntryPresentation.retryLabel(voice) == "Process again")
        voice.status = .running
        #expect(!HistoryEntryPresentation.canRetry(voice, hasAudio: true))

        var text = HistoryEntry(action: .init(shortcutName: .init("history-presentation")), status: .failed)
        #expect(!HistoryEntryPresentation.canRetry(text, hasAudio: false))
        text.sourceText = "original"
        #expect(HistoryEntryPresentation.canRetry(text, hasAudio: false))
    }

    @Test
    func deliveryLabelsDoNotClaimThatReceivingAppAcceptedPaste() {
        var entry = HistoryEntry(action: .dictation(), status: .succeeded, delivery: .pasteSent)
        #expect(HistoryEntryPresentation.status(entry) == "Paste sent")
        entry.delivery = .copied
        #expect(HistoryEntryPresentation.status(entry) == "Copied to clipboard")
        entry.delivery = .historyOnly
        #expect(HistoryEntryPresentation.status(entry) == "Saved to History")
        entry.status = .interrupted
        #expect(HistoryEntryPresentation.status(entry) == "Interrupted")
    }

    @Test @MainActor
    func historyWindowUsesIndependentNativeChromeAndSafeMinimumSize() {
        let window = HistoryWindowFactory.make(rootView: Color.clear, frameAutosaveName: nil)
        defer { window.close() }
        #expect(window.title == "History")
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.resizable))
        #expect(window.minSize.width >= 680)
        #expect(!window.isReleasedWhenClosed)
        #expect(window.titlebarAccessoryViewControllers.isEmpty)
    }

}
