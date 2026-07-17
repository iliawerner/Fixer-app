import Cocoa
import Carbon

/// Result of attempting to read the current selection via a synthetic Cmd+C.
struct Selection: Sendable {
    /// The copied text (empty if nothing was selected).
    let text: String
    /// True if the pasteboard actually changed — i.e. the copy landed. False means
    /// the copy never reached the target (no selection, missing permission, or a
    /// very slow app), which the caller treats differently from "empty selection".
    let didCopy: Bool
}

/// All pasteboard / synthetic-keystroke work is funnelled through a single serial
/// queue. That guarantees:
///  * no data race on the backup state (previously a shared array mutated from
///    concurrent background tasks),
///  * the blocking waits below never occupy a Swift-concurrency cooperative-pool
///    thread (they run on this dedicated queue instead).
/// `@unchecked Sendable` is sound because every access to mutable state happens on
/// `queue`.
final class ClipboardManager: @unchecked Sendable {
    static let shared = ClipboardManager()

    private let queue = DispatchQueue(label: "com.geminimacros.clipboard")
    private let pasteboard = NSPasteboard.general

    // Backup state — only touched on `queue`.
    private var backup: [NSPasteboardItem] = []
    private var didBackup = false
    /// The pasteboard changeCount produced by our most recent own write. Used to
    /// detect whether the user changed the clipboard out from under us (e.g. a
    /// manual Cmd+C during the Gemini round-trip) so we don't clobber it.
    private var ownChangeCount = -1

    private init() {}

    // MARK: - Public async API

    /// Backs up the current clipboard, copies the selection, and returns it.
    /// The backup is held internally until `paste(_:)` or `restore()` is called.
    func copySelection() async -> Selection {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.copySelectionSync())
            }
        }
    }

    /// Pastes `text` into the frontmost app, then restores the user's clipboard.
    func paste(_ text: String) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.pasteSync(text)
                continuation.resume()
            }
        }
    }

    /// Restores the backup without pasting (used on error / abort paths so the
    /// user's clipboard is never left holding the copied selection).
    func restore() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.restoreIfUntouched()
                continuation.resume()
            }
        }
    }

    // MARK: - Synchronous implementation (runs on `queue`)

    private func copySelectionSync() -> Selection {
        createBackup()
        // If the user triggered a multi-modifier hotkey, the extra modifiers may
        // still be physically held; posting Cmd+C now would be read as e.g.
        // Cmd+Shift+C. Wait (generously) for the keys to be released first.
        waitForModifiersToClear()

        let initialCount = pasteboard.changeCount
        simulateKeystroke(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        // Poll for the copy to land. A generous window handles slow apps
        // (Electron, web views) without misreading them as an empty selection.
        let didChange = waitForChange(from: initialCount, timeout: 0.6)

        // Record the state we produced so a later restore can tell whether the
        // user changed the clipboard in the meantime.
        ownChangeCount = pasteboard.changeCount

        if didChange, let text = pasteboard.string(forType: .string) {
            return Selection(text: text, didCopy: true)
        }
        return Selection(text: "", didCopy: didChange)
    }

    private func pasteSync(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ownChangeCount = pasteboard.changeCount // our write

        simulateKeystroke(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        // Give the target app time to service the asynchronous paste before we put
        // the user's original clipboard back. Matched to the copy path's slow-app
        // budget so a sluggish target (browser/Electron paste listener) doesn't
        // read the restored contents instead of the pasted result.
        Thread.sleep(forTimeInterval: 0.5)
        restoreIfUntouched()
    }

    // MARK: - Backup / restore

    private func createBackup() {
        backup.removeAll()
        didBackup = true
        guard let items = pasteboard.pasteboardItems else { return }
        for item in items {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            backup.append(copy)
        }
    }

    /// Restores the pre-macro clipboard, but only if the clipboard still holds
    /// what *we* last wrote. If the user copied something new during the run, that
    /// newer content is left untouched rather than clobbered.
    private func restoreIfUntouched() {
        guard didBackup else { return }
        defer { resetBackup() }

        // The user (or another app) changed the clipboard after our last write —
        // don't overwrite their newer content.
        if pasteboard.changeCount != ownChangeCount { return }

        pasteboard.clearContents()
        if !backup.isEmpty {
            pasteboard.writeObjects(backup)
        }
        // If the pre-macro clipboard was empty, clearContents() above already
        // returned it to empty — which correctly removes the copied selection /
        // pasted result instead of leaving it behind.
    }

    private func resetBackup() {
        backup.removeAll()
        didBackup = false
        ownChangeCount = -1
    }

    // MARK: - Low-level helpers

    private func waitForChange(from initialCount: Int, timeout: TimeInterval) -> Bool {
        let step: TimeInterval = 0.01
        var elapsed: TimeInterval = 0
        while pasteboard.changeCount == initialCount && elapsed < timeout {
            Thread.sleep(forTimeInterval: step)
            elapsed += step
        }
        return pasteboard.changeCount != initialCount
    }

    private func waitForModifiersToClear() {
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let step: TimeInterval = 0.01
        var elapsed: TimeInterval = 0
        let timeout: TimeInterval = 0.7
        while elapsed < timeout {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection(relevant).isEmpty { break }
            Thread.sleep(forTimeInterval: step)
            elapsed += step
        }
    }

    private func simulateKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
