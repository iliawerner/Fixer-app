import Testing
import AppKit
import Carbon
@testable import fixer

/// Exercises the restore invariant — the code that can eat a user's clipboard —
/// against a private named pasteboard, with the synthetic keystroke replaced by a
/// spy that simulates the copy landing. No real clipboard or HID events involved.
struct ClipboardManagerTests {

    private func namedPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("fixer-test-\(UUID().uuidString)"))
    }

    /// Simulates Command-C while leaving Command-V to consume the payload already
    /// written by `ClipboardManager`.
    private func manager(_ pb: NSPasteboard, copies text: String) -> ClipboardManager {
        ClipboardManager(
            pasteboard: pb,
            performKeystroke: { keyCode, _ in
                guard keyCode == CGKeyCode(kVK_ANSI_C) else { return }
                pb.clearContents()
                pb.setString(text, forType: .string)
            },
            copyTimeout: 0.2, pasteSettle: 0.01, modifierTimeout: 0.0
        )
    }

    @Test func restoresOriginalWhenUntouched() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)

        let cm = manager(pb, copies: "selection")
        let selection = await cm.copySelection()
        #expect(selection.text == "selection")
        #expect(selection.didCopy == true)
        #expect(pb.string(forType: .string) == "original")

        await cm.restore()
        #expect(pb.string(forType: .string) == "original")
    }

    @Test func doesNotClobberAConcurrentUserCopy() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)

        let cm = manager(pb, copies: "selection")
        _ = await cm.copySelection()

        // The user copies something new during the round-trip.
        pb.clearContents(); pb.setString("user-copied", forType: .string)

        await cm.restore()
        #expect(pb.string(forType: .string) == "user-copied")  // newer content preserved
    }

    @Test func pastePreservesAUserCopyMadeDuringTheNetworkWait() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)

        var payloadObservedByPaste: String?
        let cm = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { keyCode, _ in
                if keyCode == CGKeyCode(kVK_ANSI_C) {
                    pb.clearContents()
                    pb.setString("selection", forType: .string)
                } else if keyCode == CGKeyCode(kVK_ANSI_V) {
                    payloadObservedByPaste = pb.string(forType: .string)
                }
            },
            copyTimeout: 0.2,
            pasteSettle: 0.01,
            modifierTimeout: 0.0
        )

        _ = await cm.copySelection()
        #expect(pb.string(forType: .string) == "original")

        // This represents an ordinary user Copy while Gemini is responding.
        pb.clearContents(); pb.setString("user-copied", forType: .string)

        await cm.paste("generated result")

        #expect(payloadObservedByPaste == "generated result")
        #expect(pb.string(forType: .string) == "user-copied")
    }

    @Test func pasteDoesNotClobberANewerWriteMadeDuringSettle() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("copy from network wait", forType: .string)

        var payloadObservedByPaste: String?
        let cm = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { keyCode, _ in
                guard keyCode == CGKeyCode(kVK_ANSI_V) else { return }
                payloadObservedByPaste = pb.string(forType: .string)

                // Another app writes after Fixer posts Command-V but before the
                // settle interval ends. Its higher changeCount must win.
                pb.clearContents()
                pb.setString("newer external write", forType: .string)
            },
            copyTimeout: 0.2,
            pasteSettle: 0.01,
            modifierTimeout: 0.0
        )

        await cm.paste("generated result")

        #expect(payloadObservedByPaste == "generated result")
        #expect(pb.string(forType: .string) == "newer external write")
    }

    @Test func emptyOriginalClipboardEndsEmpty() async {
        let pb = namedPasteboard()
        pb.clearContents()

        let cm = manager(pb, copies: "selection")
        _ = await cm.copySelection()
        await cm.restore()

        #expect(pb.string(forType: .string) == nil)  // copied selection not left behind
    }

    @Test func reportsDidCopyFalseWhenNothingLands() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)

        // Keystroke does nothing → clipboard never changes → the copy "didn't land".
        let cm = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in },
                                  copyTimeout: 0.05, pasteSettle: 0.01, modifierTimeout: 0.0)
        let selection = await cm.copySelection()

        #expect(selection.didCopy == false)
        #expect(selection.text == "")
    }

    @Test func safeFallbackLeavesResultWithoutPostingAKey() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("previous", forType: .string)
        var postedKeys: [CGKeyCode] = []
        let manager = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { keyCode, _ in postedKeys.append(keyCode) },
            copyTimeout: 0.01,
            pasteSettle: 0.01,
            modifierTimeout: 0
        )

        await manager.copyText("voice result")
        await manager.restore()

        #expect(pb.string(forType: .string) == "voice result")
        #expect(postedKeys.isEmpty)
    }

    @Test func cancellingPendingModifierWaitPostsNoCopyKey() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)
        let (waitEvents, waitContinuation) = AsyncStream.makeStream(of: Void.self)
        let manager = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { _, _ in
                Issue.record("A cancelled pending Copy must not post a key")
            },
            copyTimeout: 0.01,
            pasteSettle: 0.01,
            modifierTimeout: 0.5,
            readModifierFlags: {
                waitContinuation.yield()
                return .maskCommand
            }
        )

        let task = Task { await manager.copySelection() }
        var waitIterator = waitEvents.makeAsyncIterator()
        _ = await waitIterator.next()
        task.cancel()
        let selection = await task.value
        waitContinuation.finish()

        #expect(!selection.didCopy)
        #expect(selection.text.isEmpty)
        #expect(pb.string(forType: .string) == "original")
    }

    @Test func modifiersThatNeverClearPostNoContaminatedCopyKey() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)
        let manager = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { _, _ in
                Issue.record("Copy must fail closed while Shortcut modifiers remain held")
            },
            copyTimeout: 0.01,
            pasteSettle: 0.01,
            modifierTimeout: 0.02,
            readModifierFlags: { .maskCommand }
        )

        let selection = await manager.copySelection()

        #expect(!selection.didCopy)
        #expect(pb.string(forType: .string) == "original")
    }

    @Test func cancellationAfterCopyKeyStillWaitsForRestore() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("original", forType: .string)
        let (copyEvents, copyContinuation) = AsyncStream.makeStream(of: Void.self)
        let manager = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { keyCode, _ in
                guard keyCode == CGKeyCode(kVK_ANSI_C) else { return }
                copyContinuation.yield()
                Thread.sleep(forTimeInterval: 0.04)
                pb.clearContents()
                pb.setString("selection", forType: .string)
            },
            copyTimeout: 0.2,
            pasteSettle: 0.01,
            modifierTimeout: 0
        )

        let task = Task { await manager.copySelection() }
        var copyIterator = copyEvents.makeAsyncIterator()
        _ = await copyIterator.next()
        task.cancel()
        let selection = await task.value
        copyContinuation.finish()

        #expect(selection.text == "selection")
        #expect(pb.string(forType: .string) == "original")
    }

    @Test func copyMadeDuringModifierWaitBecomesTheRestoreValue() async {
        let pb = namedPasteboard()
        pb.clearContents(); pb.setString("old clipboard", forType: .string)
        var modifierChecks = 0
        let manager = ClipboardManager(
            pasteboard: pb,
            performKeystroke: { keyCode, _ in
                guard keyCode == CGKeyCode(kVK_ANSI_C) else { return }
                pb.clearContents()
                pb.setString("selected text", forType: .string)
            },
            copyTimeout: 0.05,
            pasteSettle: 0.01,
            modifierTimeout: 0.1,
            readModifierFlags: {
                defer { modifierChecks += 1 }
                guard modifierChecks == 0 else { return [] }
                pb.clearContents()
                pb.setString("new user copy", forType: .string)
                return .maskCommand
            }
        )

        let selection = await manager.copySelection()

        #expect(selection.text == "selected text")
        #expect(pb.string(forType: .string) == "new user copy")
    }
}
