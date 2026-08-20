import SwiftUI
import KeyboardShortcuts

/// Records the Action's only visible shortcut and reports concrete in-app
/// collisions directly beneath it. Cross-app limitations stay in contextual
/// help rather than looking like a permanent warning.
struct ActionEditorShortcutControl: View {
    let shortcutName: KeyboardShortcuts.Name
    let conflictingActionName: String?
    let onShortcutChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActionEditorSectionLabel("Shortcut")

            KeyboardShortcuts.Recorder(for: shortcutName) { _ in
                onShortcutChanged()
            }
            .controlSize(.regular)
            .accessibilityHint("Click to record a global shortcut")

            if let conflictingActionName {
                Label {
                    Text("Also used by “\(conflictingActionName)”. Choose another shortcut.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(Fixer.safeText)
                .accessibilityLabel("Shortcut conflict with \(conflictingActionName)")
            } else {
                Label("Run this action from any app.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Fixer.muted)
                    .help("Fixer can detect conflicts between its actions, but not shortcuts used by other apps.")
            }
        }
    }
}
