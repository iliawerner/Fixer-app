import Cocoa
import Carbon

/// Cross-thread cancellation flag for the short blocking modifier wait.
private final class ClipboardWaitCancellation: @unchecked Sendable {
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

/// Coordinates validated paste and explicit copy operations. Clipboard backup
/// state and modifier waits are confined to a serial queue. Target validation
/// and the synthetic Paste event run together on the main actor.
///
/// Paste takes a fresh backup after the request, and restores it only while its
/// own changeCount still matches. A newer user or external clipboard write wins.
final class ClipboardManager: @unchecked Sendable {
    // MARK: - Shared manager and configuration

    static let shared = ClipboardManager()

    private let queue = DispatchQueue(label: "com.geminimacros.clipboard")
    private let pasteboard: NSPasteboard
    private let performKeystroke: (CGKeyCode, CGEventFlags) -> Void
    private let pasteSettle: TimeInterval
    private let modifierTimeout: TimeInterval
    private let readModifierFlags: () -> CGEventFlags

    // MARK: - Serialized transaction state

    // Only touch these properties on `queue`.
    private var backup: [NSPasteboardItem] = []
    private var didBackup = false
    /// The `changeCount` after the latest result-write stage initiated by
    /// Fixer. It protects changes made after that stage; Fixer never reserves the
    /// pasteboard across the network round-trip.
    private var ownChangeCount = -1

    /// Creates a clipboard transaction manager with injectable system boundaries.
    ///
    /// - Parameters:
    ///   - pasteboard: the pasteboard to drive. Inject a named test pasteboard so
    ///     tests never touch the user's real clipboard.
    ///   - performKeystroke: posts a synthetic key combo. Defaults to real CGEvents;
    ///     inject a spy in tests to inspect the paste without HID events.
    ///   - pasteSettle / modifierTimeout: the timing budget — shrink
    ///     these in tests so the blocking waits don't slow the suite.
    init(pasteboard: NSPasteboard = .general,
         performKeystroke: ((CGKeyCode, CGEventFlags) -> Void)? = nil,
         pasteSettle: TimeInterval = 0.5,
         modifierTimeout: TimeInterval = 0.7,
         readModifierFlags: (() -> CGEventFlags)? = nil) {
        self.pasteboard = pasteboard
        self.pasteSettle = pasteSettle
        self.modifierTimeout = modifierTimeout
        self.performKeystroke = performKeystroke ?? ClipboardManager.postSystemKeystroke
        self.readModifierFlags = readModifierFlags ?? {
            CGEventSource.flagsState(.combinedSessionState)
        }
    }

    // MARK: - Public async API

    /// Places a finished result on the clipboard without synthesizing a paste.
    ///
    /// Text and voice runs use this fallback when the original target changed
    /// or could not be verified. Overwriting the clipboard is
    /// intentional and user-visible in that branch: it is safer than typing the
    /// result into an unrelated target.
    @discardableResult
    func copyText(_ text: String) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                self.resetBackup()
                self.pasteboard.clearContents()
                let written = self.pasteboard.setString(text, forType: .string)
                continuation.resume(returning: written)
            }
        }
    }

    /// Stage the pasteboard on its queue, then revalidate on the main actor
    /// immediately before posting the key. No actor suspension separates that
    /// check and the event. A failed check restores the staged clipboard.
    @MainActor
    func paste(_ text: String, ifTargetCurrent validate: @escaping @MainActor () -> Bool) async -> Bool {
        guard !Task.isCancelled, validate() else { return false }
        let cancellation = ClipboardWaitCancellation()
        let stagedCount: Int? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    guard self.waitForModifiersToClear(cancellation: cancellation) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    self.createBackup()
                    self.pasteboard.clearContents()
                    let written = self.pasteboard.setString(text, forType: .string)
                    self.ownChangeCount = self.pasteboard.changeCount
                    guard written else {
                        self.restoreIfUntouched()
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: self.ownChangeCount)
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
        guard let stagedCount else { return false }
        guard !Task.isCancelled, validate(), pasteboard.changeCount == stagedCount else {
            await restore()
            return false
        }
        performKeystroke(CGKeyCode(kVK_ANSI_V), .maskCommand)
        await withCheckedContinuation { continuation in
            queue.asyncAfter(deadline: .now() + pasteSettle) {
                self.restoreIfUntouched()
                continuation.resume()
            }
        }
        return true
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

    private func waitForModifiersToClear(
        cancellation: ClipboardWaitCancellation
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
