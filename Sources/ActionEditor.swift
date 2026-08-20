import SwiftUI

/// Resolves the selected Action into a live array binding.
///
/// Every edit is written back through a stable-id Binding so autosave stays
/// live without retaining an array index across deletion or reordering.
struct ActionDetailPane: View {
    @ObservedObject var settings: SettingsManager

    let actionID: UUID
    let models: [GeminiModel]
    @Binding var shortcutRevision: Int
    let onSelectAction: (UUID) -> Void
    let onShortcutChanged: () -> Void
    let onDeleteAction: ((UUID) -> Void)?

    init(
        settings: SettingsManager,
        actionID: UUID,
        models: [GeminiModel],
        shortcutRevision: Binding<Int>,
        onSelectAction: @escaping (UUID) -> Void,
        onShortcutChanged: @escaping () -> Void,
        onDeleteAction: ((UUID) -> Void)? = nil
    ) {
        self.settings = settings
        self.actionID = actionID
        self.models = models
        _shortcutRevision = shortcutRevision
        self.onSelectAction = onSelectAction
        self.onShortcutChanged = onShortcutChanged
        self.onDeleteAction = onDeleteAction
    }

    /// Resolves by stable id on every access. An index-backed Binding can outlive
    /// the array mutation that removes an Action while SwiftUI tears down its
    /// TextField, turning a harmless delete into an out-of-bounds access.
    private var actionBinding: Binding<MacroAction>? {
        guard let snapshot = settings.actions.first(where: { $0.id == actionID }) else {
            return nil
        }

        return Binding(
            get: {
                settings.actions.first(where: { $0.id == actionID }) ?? snapshot
            },
            set: { updatedAction in
                guard let currentIndex = settings.actions.firstIndex(where: { $0.id == actionID }) else {
                    return
                }
                settings.actions[currentIndex] = updatedAction
            }
        )
    }

    var body: some View {
        Group {
            if let actionBinding {
                if actionBinding.wrappedValue.kind == .dictation {
                    DictationEditorContent(
                        settings: settings,
                        action: actionBinding,
                        shortcutRevision: $shortcutRevision,
                        onShortcutChanged: onShortcutChanged
                    )
                } else {
                    ActionEditorContent(
                        settings: settings,
                        action: actionBinding,
                        models: models,
                        shortcutRevision: $shortcutRevision,
                        onSelectAction: onSelectAction,
                        onShortcutChanged: onShortcutChanged,
                        onDeleteAction: onDeleteAction
                    )
                }
            } else {
                Color.clear
            }
        }
        .background(Fixer.panel)
    }
}
