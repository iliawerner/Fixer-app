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

    private func action(_ shortcutName: String, isEnabled: Bool = true) -> MacroAction {
        MacroAction(
            name: shortcutName,
            shortcutName: KeyboardShortcuts.Name(shortcutName),
            isEnabled: isEnabled
        )
    }
}
