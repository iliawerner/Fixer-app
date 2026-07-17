import AppKit
import ApplicationServices

/// Accessibility (AXIsProcessTrusted) is required to post synthetic Cmd+C / Cmd+V
/// keystrokes to other applications. Without it, CGEvent.post silently succeeds
/// but the event is never delivered — which is why the app appears "dead" on a
/// fresh machine until the user grants the permission.
enum PermissionsManager {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system Accessibility prompt (adds the app to the list and
    /// asks the user to enable it). Returns the current trusted state.
    @discardableResult
    static func promptForAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
