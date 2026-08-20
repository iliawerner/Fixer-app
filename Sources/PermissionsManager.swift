import AppKit
import ApplicationServices

/// Accessibility (AXIsProcessTrusted) is required to post synthetic Cmd+C / Cmd+V
/// keystrokes to other applications. Without it, CGEvent.post silently succeeds
/// but the event is never delivered — which is why the app appears "dead" on a
/// fresh machine until the user grants the permission.
enum PermissionsManager {
    // MARK: - Trust state

    /// Returns a point-in-time trust value. macOS does not publish a change
    /// notification, so `AppDelegate` polls this through `AppState`.
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - User-directed permission flow

    /// Asks macOS to display the Accessibility prompt and returns the current
    /// trust value.
    ///
    /// Displaying the prompt does not grant access; the user must enable Fixer in
    /// System Settings.
    @discardableResult
    static func promptForAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility privacy pane without changing its setting.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
