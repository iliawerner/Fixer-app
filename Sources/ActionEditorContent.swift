import SwiftUI
import KeyboardShortcuts

/// Arranges one Action without owning a second copy of its state.
///
/// The Prompt is deliberately first in the scrolling content because it is the
/// primary work surface. Runtime and delivery settings remain close behind it,
/// but no longer push the Prompt below an oversized identity block.
struct ActionEditorContent: View {
    @ObservedObject var settings: SettingsManager
    @Binding var action: MacroAction

    let models: [GeminiModel]
    @Binding var shortcutRevision: Int
    let onSelectAction: (UUID) -> Void
    let onShortcutChanged: () -> Void
    let onDeleteAction: ((UUID) -> Void)?

    init(
        settings: SettingsManager,
        action: Binding<MacroAction>,
        models: [GeminiModel],
        shortcutRevision: Binding<Int>,
        onSelectAction: @escaping (UUID) -> Void,
        onShortcutChanged: @escaping () -> Void,
        onDeleteAction: ((UUID) -> Void)? = nil
    ) {
        self.settings = settings
        _action = action
        self.models = models
        _shortcutRevision = shortcutRevision
        self.onSelectAction = onSelectAction
        self.onShortcutChanged = onShortcutChanged
        self.onDeleteAction = onDeleteAction
    }

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ActionEditorHeader(
                action: $action,
                onDuplicate: duplicateAction,
                onRequestDelete: requestDelete
            )

            // macOS 13 has no container-relative sizing API. The viewport is
            // read here solely to let the Prompt absorb useful window growth;
            // the rest of the page keeps a stable, compact rhythm.
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ActionEditorPromptSection(
                            action: $action,
                            editorHeight: promptHeight(for: viewport.size.height)
                        )
                        .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)

                        ActionEditorRule()

                        ActionEditorRuntimeSection(
                            action: $action,
                            conflictingActionName: conflictingActionName,
                            onShortcutChanged: onShortcutChanged
                        )
                        .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)

                        ActionEditorRule()

                        ActionEditorDeliverySection(
                            action: $action,
                            models: models,
                            onEnabledChange: updateEnabledState
                        )
                        .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)
                    }
                    .frame(
                        maxWidth: ActionEditorMetrics.contentMaximumWidth,
                        alignment: .leading
                    )
                    .padding(.horizontal, ActionEditorMetrics.contentInset)
                    .padding(.bottom, ActionEditorMetrics.sectionVerticalInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic)
            }
        }
        .alert("Delete “\(displayName)”?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the prompt and its shortcut. This cannot be undone.")
        }
    }

    private var conflictingActionName: String? {
        // KeyboardShortcuts stores recorder state outside the Action model. Reading
        // the revision keeps this view synchronized after its recorder changes.
        _ = shortcutRevision
        return ActionShortcutPolicy.conflictingAction(
            for: action,
            actions: settings.actions,
            shortcutFor: KeyboardShortcuts.getShortcut
        )?.name
    }

    private var displayName: String {
        action.name.isEmpty ? "this action" : action.name
    }

    private func updateEnabledState(_ enabled: Bool) {
        settings.setEnabled(enabled, id: action.id)
    }

    private func duplicateAction() {
        if let id = settings.duplicate(id: action.id) {
            onSelectAction(id)
        }
    }

    private func requestDelete() {
        showDeleteConfirmation = true
    }

    private func deleteAction() {
        if let onDeleteAction {
            onDeleteAction(action.id)
        } else {
            settings.deleteAction(id: action.id)
        }
    }

    /// Starts near 180 points at compact sizes, then absorbs most surplus
    /// height above the default workspace. The upper bound protects the
    /// settings below it from disappearing in unusually tall windows.
    private func promptHeight(for viewportHeight: CGFloat) -> CGFloat {
        let growth = max(0, viewportHeight - 650) * 0.62
        return min(
            ActionEditorMetrics.promptDefaultHeight + growth,
            ActionEditorMetrics.promptMaximumHeight
        )
    }
}
