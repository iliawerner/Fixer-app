import KeyboardShortcuts
import Testing
@testable import fixer

/// Exercises shortcut eligibility without installing Carbon registrations or
/// mutating the KeyboardShortcuts package's process-wide UserDefaults state.
struct HotkeyCoordinatorTests {
    private let primary = KeyboardShortcuts.Shortcut(.r)
    private let secondary = KeyboardShortcuts.Shortcut(.t)

    @Test func registrationIncludesOnlyUniqueEnabledPhysicalShortcuts() {
        let first = action("first")
        let duplicate = action("duplicate")
        let unique = action("unique")
        let disabled = action("disabled", isEnabled: false)
        let noShortcut = action("none")
        let shortcuts = [
            first.shortcutName.rawValue: primary,
            duplicate.shortcutName.rawValue: primary,
            unique.shortcutName.rawValue: secondary,
            disabled.shortcutName.rawValue: KeyboardShortcuts.Shortcut(.y)
        ]

        let names = HotkeyRegistrationPolicy.namesToEnable(
            actions: [first, duplicate, unique, disabled, noShortcut],
            shortcutFor: { shortcuts[$0.rawValue] }
        )

        #expect(names.map(\.rawValue) == [unique.shortcutName.rawValue])
    }

    @Test func disabledDuplicateDoesNotSuppressTheEnabledAction() {
        let enabled = action("enabled")
        let disabled = action("disabled", isEnabled: false)
        let shortcuts = [
            enabled.shortcutName.rawValue: primary,
            disabled.shortcutName.rawValue: primary
        ]

        let names = HotkeyRegistrationPolicy.namesToEnable(
            actions: [enabled, disabled],
            shortcutFor: { shortcuts[$0.rawValue] }
        )

        #expect(names.map(\.rawValue) == [enabled.shortcutName.rawValue])
    }

    @Test func setupReadinessAllowsAnEnabledActionWithOnlyADisabledDuplicate() {
        let enabled = action("enabled")
        let disabled = action("disabled", isEnabled: false)

        let hasRunnableAction = ActionShortcutPolicy.hasRunnableAction(
            actions: [enabled, disabled],
            shortcutFor: { _ in primary }
        )

        #expect(hasRunnableAction)
        #expect(
            ActionShortcutPolicy.conflictingAction(
                for: enabled,
                actions: [enabled, disabled],
                shortcutFor: { _ in primary }
            ) == nil
        )
    }

    @Test func setupReadinessRejectsEnabledShortcutConflicts() {
        let first = action("first")
        let second = action("second")

        let hasRunnableAction = ActionShortcutPolicy.hasRunnableAction(
            actions: [first, second],
            shortcutFor: { _ in primary }
        )

        #expect(!hasRunnableAction)
    }

    @Test func firePolicyAllowsAUniqueEnabledAction() {
        let action = action("unique")

        let runnable = HotkeyRunPolicy.runnableAction(
            actionID: action.id,
            actions: [action],
            shortcutFor: { _ in primary }
        )

        #expect(runnable?.id == action.id)
    }

    @Test func firePolicyBlocksAnActionWithoutARecordedShortcut() {
        let action = action("none")

        let runnable = HotkeyRunPolicy.runnableAction(
            actionID: action.id,
            actions: [action],
            shortcutFor: { _ in nil }
        )

        #expect(runnable == nil)
    }

    @Test func firePolicyBlocksBothSidesOfAnEnabledConflict() {
        let first = action("first")
        let second = action("second")

        let firstResult = HotkeyRunPolicy.runnableAction(
            actionID: first.id,
            actions: [first, second],
            shortcutFor: { _ in primary }
        )
        let secondResult = HotkeyRunPolicy.runnableAction(
            actionID: second.id,
            actions: [first, second],
            shortcutFor: { _ in primary }
        )

        #expect(firstResult == nil)
        #expect(secondResult == nil)
    }

    @Test func firePolicyIgnoresDisabledDuplicates() {
        let enabled = action("enabled")
        let disabled = action("disabled", isEnabled: false)

        let enabledResult = HotkeyRunPolicy.runnableAction(
            actionID: enabled.id,
            actions: [enabled, disabled],
            shortcutFor: { _ in primary }
        )
        let disabledResult = HotkeyRunPolicy.runnableAction(
            actionID: disabled.id,
            actions: [enabled, disabled],
            shortcutFor: { _ in primary }
        )

        #expect(enabledResult?.id == enabled.id)
        #expect(disabledResult == nil)
    }

    @Test func physicalPressLatchRejectsRepeatsAndConsumesOnlyOneKeyUp() {
        var latch = HotkeyPressLatch<String>()

        let firstDown = latch.begin("first", for: "voice")
        let repeatedDown = latch.begin("repeat", for: "voice")
        let firstUp = latch.finish(for: "voice")
        let orphanUp = latch.finish(for: "voice")

        #expect(firstDown)
        #expect(!repeatedDown)
        #expect(firstUp == "first")
        #expect(orphanUp == nil)
    }

    @Test func reconciliationResetMakesALostKeyUpHarmless() {
        var latch = HotkeyPressLatch<Int>()
        let firstDown = latch.begin(1, for: "hold")

        latch.reset()

        let lostUp = latch.finish(for: "hold")
        let nextDown = latch.begin(2, for: "hold")
        #expect(firstDown)
        #expect(lostUp == nil)
        #expect(nextDown)
    }

    @Test func dictationAndTextActionConflictSuppressesBothRoutes() {
        let dictation = MacroAction.dictation()
        let voiceAction = MacroAction(
            name: "Voice edit",
            shortcutName: KeyboardShortcuts.Name("voice-edit"),
            promptTemplate: "Rewrite this using {voice}: {text}"
        )

        let enabled = HotkeyRegistrationPolicy.namesToEnable(
            actions: [dictation, voiceAction],
            shortcutFor: { _ in primary }
        )

        #expect(enabled.isEmpty)
    }

    @Test func activeToggleRecordingCancelsWhenItsActionBecomesUnavailable() {
        let dictation = MacroAction.dictation()
        var disabled = dictation
        disabled.isEnabled = false

        #expect(
            !HotkeyVoiceSessionPolicy.shouldCancelActiveVoice(
                activeActionID: dictation.id,
                actions: [dictation],
                shortcutFor: { _ in primary }
            )
        )
        #expect(
            HotkeyVoiceSessionPolicy.shouldCancelActiveVoice(
                activeActionID: dictation.id,
                actions: [disabled],
                shortcutFor: { _ in primary }
            )
        )
        #expect(
            HotkeyVoiceSessionPolicy.shouldCancelActiveVoice(
                activeActionID: dictation.id,
                actions: [],
                shortcutFor: { _ in primary }
            )
        )
    }

    @Test func activeVoiceSessionKeepsOwnershipAfterPromptTokenIsRemoved() {
        var action = MacroAction(
            name: "Voice edit",
            shortcutName: KeyboardShortcuts.Name("voice-owner"),
            promptTemplate: "Use {voice}"
        )
        let activeID = action.id
        action.promptTemplate = "Now a plain prompt"

        let mode = HotkeyVoiceRoutePolicy.activationMode(
            for: action,
            activeActionID: activeID,
            activeActivationMode: .toggle,
            configuredActivationMode: .hold
        )

        #expect(mode == .toggle)
    }

    private func action(_ shortcutName: String, isEnabled: Bool = true) -> MacroAction {
        MacroAction(
            name: shortcutName,
            shortcutName: KeyboardShortcuts.Name(shortcutName),
            isEnabled: isEnabled
        )
    }
}
