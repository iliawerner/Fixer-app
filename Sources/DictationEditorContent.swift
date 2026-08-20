import KeyboardShortcuts
import SwiftUI

/// Special settings for the permanent Dictation Action.
///
/// Dictation intentionally omits Prompt, model, and output mode: its one job is
/// to insert the transcript at the original cursor. The gesture configured here
/// is also used by text Actions whose Prompt contains `{voice}`.
struct DictationEditorContent: View {
    @ObservedObject var settings: SettingsManager
    @Binding var action: MacroAction
    @Binding var shortcutRevision: Int
    let onShortcutChanged: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DictationEditorHeader()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ActionEditorShortcutControl(
                        shortcutName: action.shortcutName,
                        conflictingActionName: conflictingActionName,
                        onShortcutChanged: onShortcutChanged
                    )
                    .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)

                    ActionEditorRule()

                    DictationActivationControl(mode: activationMode)
                        .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)

                    ActionEditorRule()

                    DictationPrivacySection()
                        .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)

                    ActionEditorRule()

                    ActionEditorEnabledControl(
                        action: $action,
                        onEnabledChange: updateEnabledState
                    )
                    .padding(.vertical, ActionEditorMetrics.sectionVerticalInset)
                }
                .frame(maxWidth: ActionEditorMetrics.contentMaximumWidth, alignment: .leading)
                .padding(.horizontal, ActionEditorMetrics.contentInset)
                .padding(.bottom, ActionEditorMetrics.sectionVerticalInset)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
        }
    }

    private var activationMode: Binding<VoiceActivationMode> {
        Binding(
            get: { action.voiceActivationMode },
            set: { settings.setVoiceActivationMode($0) }
        )
    }

    private var conflictingActionName: String? {
        _ = shortcutRevision
        return ActionShortcutPolicy.conflictingAction(
            for: action,
            actions: settings.actions,
            shortcutFor: KeyboardShortcuts.getShortcut
        )?.name
    }

    private func updateEnabledState(_ enabled: Bool) {
        settings.setEnabled(enabled, id: action.id)
    }
}
