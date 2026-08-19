import SwiftUI

/// The two settings users reach for most often after editing the Prompt. Their
/// order is intentionally vertical at every window size, so scanning never
/// changes direction when the window is resized.
struct ActionEditorRuntimeSection: View {
    @Binding var action: MacroAction

    let conflictingActionName: String?
    let onShortcutChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ActionEditorMetrics.settingSpacing) {
            ActionEditorShortcutControl(
                shortcutName: action.shortcutName,
                conflictingActionName: conflictingActionName,
                onShortcutChanged: onShortcutChanged
            )

            ActionEditorOutputControl(mode: $action.outputMode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
