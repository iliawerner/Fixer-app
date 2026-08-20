import Cocoa
import Carbon

// MARK: - Selection result

/// Result of attempting to read the current selection via a synthetic Cmd+C.
struct Selection: Sendable {
    /// The copied text (empty if nothing was selected).
    let text: String
    /// True if the pasteboard actually changed — i.e. the copy landed. False means
    /// the copy never reached the target (no selection, missing permission, or a
    /// very slow app), which the caller treats differently from "empty selection".
    let didCopy: Bool
}

/// Cross-thread cancellation flag for the short blocking pre-Copy wait.
///
/// The clipboard queue may be sleeping while Swift task cancellation happens on
/// another executor, so queue-confined state cannot interrupt that wait. Once
/// Command-C is posted the operation deliberately becomes non-cancellable and
/// waits long enough to restore any copied selection safely.
private final class ClipboardCopyCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

// MARK: - Clipboard transaction

/// Coordinates short copy and paste transactions on the general pasteboard using
/// synthetic keyboard events.
///
/// All mutable backup state and all blocking waits are confined to a dedicated
/// serial queue. This makes `@unchecked Sendable` sound and keeps the waits off
/// Swift concurrency's cooperative executor.
///
/// The selection-copy backup is restored immediately, before any network await.
/// Paste takes a fresh backup, so a clipboard change made while Gemini is working
/// becomes the value restored after Command-V. Every restoration remains guarded
/// by `changeCount`, allowing a still-newer external write to win.
final class ClipboardManager: @unchecked Sendable {
    // MARK: - Shared manager and configuration

    static let shared = ClipboardManager()

    private let queue = DispatchQueue(label: "com.geminimacros.clipboard")
    private let pasteboard: NSPasteboard
    private let performKeystroke: (CGKeyCode, CGEventFlags) -> Void
    private let copyTimeout: TimeInterval
    private let pasteSettle: TimeInterval
    private let modifierTimeout: TimeInterval
    private let readModifierFlags: () -> CGEventFlags

    // MARK: - Serialized transaction state

    // Only touch these properties on `queue`.
    private var backup: [NSPasteboardItem] = []
    private var didBackup = false
    /// The `changeCount` after the latest copy or result-write stage initiated by
    /// Fixer. It protects changes made after that stage; Fixer never reserves the
    /// pasteboard across the network round-trip.
    private var ownChangeCount = -1

    /// Creates a clipboard transaction manager with injectable system boundaries.
    ///
    /// - Parameters:
    ///   - pasteboard: the pasteboard to drive. Inject a named test pasteboard so
    ///     tests never touch the user's real clipboard.
    ///   - performKeystroke: posts a synthetic key combo. Defaults to real CGEvents;
    ///     inject a spy in tests to simulate a copy/paste landing without HID events.
    ///   - copyTimeout / pasteSettle / modifierTimeout: the timing budget — shrink
    ///     these in tests so the blocking waits don't slow the suite.
    init(pasteboard: NSPasteboard = .general,
         performKeystroke: ((CGKeyCode, CGEventFlags) -> Void)? = nil,
         copyTimeout: TimeInterval = 0.6,
         pasteSettle: TimeInterval = 0.5,
         modifierTimeout: TimeInterval = 0.7,
         readModifierFlags: (() -> CGEventFlags)? = nil) {
        self.pasteboard = pasteboard
        self.copyTimeout = copyTimeout
        self.pasteSettle = pasteSettle
        self.modifierTimeout = modifierTimeout
        self.performKeystroke = performKeystroke ?? ClipboardManager.postSystemKeystroke
        self.readModifierFlags = readModifierFlags ?? {
            CGEventSource.flagsState(.combinedSessionState)
        }
    }

    // MARK: - Public async API

    /// Backs up every current pasteboard item, posts Command-C to the focused
    /// application, captures the copied text, and restores the backup immediately.
    /// The selected text therefore does not remain in the pasteboard during the
    /// subsequent network request.
    func copySelection() async -> Selection {
        let cancellation = ClipboardCopyCancellation()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(
                        returning: self.copySelectionSync(cancellation: cancellation)
                    )
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// Takes a fresh backup of the current pasteboard, replaces it with `text`,
    /// posts Command-V to the currently focused application, then conditionally
    /// restores that fresh backup.
    ///
    /// This method does not retain the application or control that originally
    /// supplied the selection.
    func paste(_ text: String) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.pasteSync(text)
                continuation.resume()
            }
        }
    }

    /// Places a finished result on the clipboard without synthesizing a paste.
    ///
    /// Voice runs use this fail-safe when the original app or focused control
    /// changed while recording/transcribing. Overwriting the clipboard is
    /// intentional and user-visible in that branch: it is safer than typing the
    /// result into an unrelated target.
    func copyText(_ text: String) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.resetBackup()
                self.pasteboard.clearContents()
                self.pasteboard.setString(text, forType: .string)
                continuation.resume()
            }
        }
    }

    /// Attempts to restore any current operation-stage backup without pasting.
    ///
    /// Used on abort and error paths. If the pasteboard changed after Fixer's
    /// latest operation stage, the newer contents win and the backup is discarded.
    func restore() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.restoreIfUntouched()
                continuation.resume()
            }
        }
    }

    // MARK: - Synchronous implementation (runs on `queue`)

    private func copySelectionSync(
        cancellation: ClipboardCopyCancellation
    ) -> Selection {
        // If the user triggered a multi-modifier hotkey, the extra modifiers may
        // still be physically held; posting Cmd+C now would be read as e.g.
        // Cmd+Shift+C. Wait (generously) for the keys to be released first.
        guard waitForModifiersToClear(cancellation: cancellation) else {
            return Selection(text: "", didCopy: false)
        }

        // Capture the clipboard only after the modifier wait. A user Copy made
        // during that wait is now the value restored after our short transaction.
        createBackup()
        guard !cancellation.isCancelled else {
            resetBackup()
            return Selection(text: "", didCopy: false)
        }

        let initialCount = pasteboard.changeCount
        performKeystroke(CGKeyCode(kVK_ANSI_C), .maskCommand)

        // Poll for the copy to land. A generous window handles slow apps
        // (Electron, web views) without misreading them as an empty selection.
        let didChange = waitForChange(from: initialCount, timeout: copyTimeout)

        // Record the state we produced so a later restore can tell whether the
        // user changed the clipboard in the meantime.
        ownChangeCount = pasteboard.changeCount

        let selection: Selection
        if didChange, let text = pasteboard.string(forType: .string) {
            selection = Selection(text: text, didCopy: true)
        } else {
            selection = Selection(text: "", didCopy: didChange)
        }

        // Do not expose the selection through the shared pasteboard for the
        // duration of the network request. A later paste takes its own fresh backup.
        restoreIfUntouched()
        return selection
    }

    private func pasteSync(_ text: String) {
        // Capture what the clipboard contains now, not what it contained when the
        // shortcut fired. This preserves a Copy made while Gemini was working.
        createBackup()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ownChangeCount = pasteboard.changeCount // our write

        performKeystroke(CGKeyCode(kVK_ANSI_V), .maskCommand)

        // Give the target app time to service the asynchronous paste before we put
        // the user's original clipboard back. Matched to the copy path's slow-app
        // budget so a sluggish target (browser/Electron paste listener) doesn't
        // read the restored contents instead of the pasted result.
        Thread.sleep(forTimeInterval: pasteSettle)
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

    /// Restores the current stage's backup only if the pasteboard still contains
    /// the state produced by Fixer's latest operation stage.
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
        // If the stage backup was empty, clearContents() above already
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

    private func waitForModifiersToClear(
        cancellation: ClipboardCopyCancellation
    ) -> Bool {
        // Tests and callers that explicitly opt out of the wait retain the old
        // immediate behavior without consulting global keyboard state.
        guard modifierTimeout > 0 else { return !cancellation.isCancelled }

        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let step: TimeInterval = 0.01
        var elapsed: TimeInterval = 0
        while elapsed < modifierTimeout {
            if cancellation.isCancelled { return false }
            let flags = readModifierFlags()
            if flags.intersection(relevant).isEmpty { return true }
            Thread.sleep(forTimeInterval: step)
            elapsed += step
        }
        guard !cancellation.isCancelled else { return false }
        return readModifierFlags().intersection(relevant).isEmpty
    }

    /// Default keystroke implementation: post a real synthetic key combo through
    /// the HID event tap. Swapped for a spy in tests.
    private static func postSystemKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
