import SwiftUI

/// Secondary execution settings continue the editor's single vertical reading
/// path: model first, followed by the Action's canonical enabled switch.
struct ActionEditorDeliverySection: View {
    @Binding var action: MacroAction
    let models: [GeminiModel]
    let onEnabledChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ActionEditorMetrics.settingSpacing) {
            ActionEditorModelControl(action: $action, models: models)

            ActionEditorEnabledControl(
                action: $action,
                onEnabledChange: onEnabledChange
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Kept on the section as a stable formatting seam for tests and previews.
    static func modelMenuLabel(for model: GeminiModel) -> String {
        ActionEditorModelControl.modelMenuLabel(for: model)
    }
}
