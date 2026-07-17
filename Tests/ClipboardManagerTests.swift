import Testing
import AppKit
@testable import fixer

/// Exercises the restore invariant — the code that can eat a user's clipboard —
/// against a private named pasteboard, with the synthetic keystroke replaced by a
/// spy that simulates the copy landing. No real clipboard or HID events involved.
struct ClipboardManagerTests {

    private func namedPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("fixer-test-\(UUID().uuidString)"))
    }

    /// Copy the selection, and if the clipboard still holds our write, restore the
    /// user's original contents.
    private func manager(_ pb: NSPasteboard, copies text: String) -> ClipboardManager {
        ClipboardManager(
            pasteboard: pb,
            performKeystroke: { _, _ in pb.clearContents(); pb.setString(text, forType: .string) },
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
