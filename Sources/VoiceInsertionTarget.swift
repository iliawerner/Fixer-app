import AppKit
import ApplicationServices

/// Snapshot of the app and accessibility element that owned the cursor when a
/// voice shortcut began. The AX reference never leaves the main actor.
@MainActor
struct VoiceInsertionTarget {
    fileprivate let application: NSRunningApplication
    let processIdentifier: pid_t
    fileprivate let focusedElement: AXUIElement?
    /// The original insertion/selection range. Element identity alone is not
    /// enough: a user can move the caret elsewhere inside the same text field
    /// while Gemini is transcribing.
    fileprivate let selectedTextRange: CFRange?

    /// Lets the runner distinguish a collapsed caret from a non-empty or
    /// unverifiable selection without exposing the AX value across layers.
    var selectionLength: Int? { selectedTextRange?.length }
}

/// Captures and later verifies a voice run's insertion destination.
///
/// Recording is long enough that a user can naturally switch apps. Fixer never
/// steals focus back; a changed target turns delivery into an explicit clipboard
/// copy instead of sending Command-V to an unrelated control.
@MainActor
protocol VoiceInsertionTargeting: AnyObject {
    func capture() -> VoiceInsertionTarget?
    func isCurrent(_ target: VoiceInsertionTarget) -> Bool
    func selectedText(in target: VoiceInsertionTarget) -> String?
}

@MainActor
final class SystemVoiceInsertionTarget: VoiceInsertionTargeting {
    func capture() -> VoiceInsertionTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        let pid = application.processIdentifier
        let element = focusedElement(for: pid)
        return VoiceInsertionTarget(
            application: application,
            processIdentifier: pid,
            focusedElement: element,
            selectedTextRange: element.flatMap { selectedTextRange(in: $0) }
        )
    }

    func isCurrent(_ target: VoiceInsertionTarget) -> Bool {
        guard let currentApplication = NSWorkspace.shared.frontmostApplication,
              currentApplication.isEqual(target.application),
              currentApplication.processIdentifier == target.processIdentifier else {
            return false
        }

        // PID-only verification fails open when the user changes fields inside
        // one app. An unavailable AX element is therefore unverifiable and must
        // use the clipboard fallback rather than automatic paste.
        guard let original = target.focusedElement,
              let originalRange = target.selectedTextRange else { return false }
        guard let current = focusedElement(for: target.processIdentifier) else {
            return false
        }
        guard CFEqual(original, current),
              let currentRange = selectedTextRange(in: current) else { return false }
        return VoiceInsertionTargetPolicy.rangesMatch(originalRange, currentRange)
    }

    func selectedText(in target: VoiceInsertionTarget) -> String? {
        // The AX reference remains readable after focus moves. Verify both
        // before and after the read so the returned text is guaranteed to come
        // from the originally captured field and range, not a later selection.
        guard isCurrent(target), let element = target.focusedElement else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        ) == .success,
        isCurrent(target) else {
            return nil
        }
        return value as? String
    }

    private func focusedElement(for pid: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success,
        let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        var elementPID: pid_t = 0
        guard AXUIElementGetPid(element, &elementPID) == .success,
              elementPID == pid else { return nil }
        return element
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
}

/// Pure policy seam for unit tests that cannot create another application's AX
/// hierarchy inside the hosted test process.
enum VoiceInsertionTargetPolicy {
    static func isCurrent(
        originalPID: pid_t,
        currentPID: pid_t?,
        originalHadElement: Bool,
        elementsMatch: Bool,
        rangesMatch: Bool = true
    ) -> Bool {
        guard currentPID == originalPID else { return false }
        return originalHadElement && elementsMatch && rangesMatch
    }

    static func rangesMatch(_ original: CFRange, _ current: CFRange) -> Bool {
        original.location == current.location && original.length == current.length
    }
}
