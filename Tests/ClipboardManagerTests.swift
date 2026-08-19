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
}
