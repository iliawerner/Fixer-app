import Foundation
import KeyboardShortcuts

/// Small, package-independent edge detector for global shortcut callbacks.
///
/// KeyboardShortcuts forwards raw key-down events and does not expose an
/// `isRepeat` flag. Keeping this latch separate makes the physical contract
/// testable without registering Carbon hotkeys in the test process.
struct HotkeyPressLatch<Value> {
    private var values: [String: Value] = [:]

    var isEmpty: Bool { values.isEmpty }

    mutating func begin(_ value: Value, for key: String) -> Bool {
        guard values[key] == nil else { return false }
        values[key] = value
        return true
    }

    mutating func finish(for key: String) -> Value? {
        values.removeValue(forKey: key)
    }

    mutating func reset() {
        values.removeAll()
    }
}

/// Owns the lifetime of global-shortcut handlers. Invariants a change here must
/// preserve:
///
/// - Startup binds saved actions independently of whether the workspace opens.
/// - Legacy key callbacks append handlers, so `bind(...)` remains idempotent for
///   each shortcut name even though KeyboardShortcuts 2.4 can now remove them.
/// - Key-down callbacks carry no repeat flag. A coordinator-owned press latch is
///   the edge detector for both toggle and hold-to-talk behavior.
/// - A handler resolves the *current* action by id at fire time rather than a
///   captured copy, so edits to the prompt/model/mode take effect without
///   re-binding.
/// - KeyboardShortcuts registers physical combinations globally, not per Name.
///   Reconciliation therefore clears all saved Names before restoring the
///   unique enabled set; changing one duplicate must not strand another action.
@MainActor
final class HotkeyCoordinator {
    // MARK: - Shared coordinator and handler lifetime

    static let shared = HotkeyCoordinator()

    private struct PressedShortcut {
        let action: MacroAction
        let voiceMode: VoiceActivationMode?
    }

    // One entry per Name whose pair of callbacks is currently installed.
    private var registered = Set<String>()
    /// Physical key-edge latch. Carbon can forward repeated raw key-down events
    /// while a menu tracks; only the first down and its matching up are semantic.
    private var pressed = HotkeyPressLatch<PressedShortcut>()

    private init() {}

    /// Registers handlers for the actions loaded at process startup.
    ///
    /// Reconciliation is deliberately part of startup: `onKeyUp` registers a
    /// saved combination as a side effect, including combinations belonging to
    /// disabled actions.
    func bindAll() {
        reconcile(actions: SettingsManager.shared.actions)
    }

    /// Registers one down/up callback pair for a shortcut identity.
    private func bind(name: KeyboardShortcuts.Name, actionID: UUID) {
        let key = name.rawValue
        guard !registered.contains(key) else { return }
        registered.insert(key)

        KeyboardShortcuts.onKeyDown(for: name) {
            // GCD's main queue preserves the physical event order. Two detached
            // actor Tasks created for a very quick tap are not specified to run
            // FIFO and could otherwise observe key-up before key-down.
            DispatchQueue.main.async {
                self.handleKeyDown(name: name, actionID: actionID)
            }
        }
        KeyboardShortcuts.onKeyUp(for: name) {
            DispatchQueue.main.async {
                self.handleKeyUp(name: name)
            }
        }
    }

    private func handleKeyDown(name: KeyboardShortcuts.Name, actionID: UUID) {
        let key = name.rawValue
        guard let current = HotkeyRunPolicy.runnableAction(
                actionID: actionID,
                actions: SettingsManager.shared.actions,
                shortcutFor: KeyboardShortcuts.getShortcut
              ) else { return }

        let voiceMode = HotkeyVoiceRoutePolicy.activationMode(
            for: current,
            activeActionID: VoiceActionRunner.shared.activeActionID,
            activeActivationMode: VoiceActionRunner.shared.activeActivationMode,
            configuredActivationMode: SettingsManager.shared.voiceActivationMode
        )
        let press = PressedShortcut(action: current, voiceMode: voiceMode)
        guard pressed.begin(press, for: key) else { return }

        if voiceMode == .hold {
            VoiceActionRunner.shared.beginHold(action: current)
        }
    }

    private func handleKeyUp(name: KeyboardShortcuts.Name) {
        let key = name.rawValue
        guard let press = pressed.finish(for: key) else { return }

        switch press.voiceMode {
        case .hold:
            // The owning key-up must stop hold-to-talk even if settings changed
            // or the Action was disabled during the press.
            VoiceActionRunner.shared.endHold(actionID: press.action.id)
        case .toggle:
            VoiceActionRunner.shared.toggle(action: press.action)
        case nil:
            guard let current = HotkeyRunPolicy.runnableAction(
                actionID: press.action.id,
                actions: SettingsManager.shared.actions,
                shortcutFor: KeyboardShortcuts.getShortcut
            ) else { return }
            ActionRunner.shared.run(action: current)
        }
    }

    /// Restores package registration from the complete current Action snapshot.
    ///
    /// KeyboardShortcuts tracks one Carbon registration per physical shortcut.
    /// Its Recorder first unregisters a Name's old combination, which also
    /// removes that combination for any other Name sharing it. Disabling all
    /// saved Names before enabling only unique enabled combinations gives us a
    /// deterministic package state after recording, enabling, disabling, or
    /// deleting.
    func reconcile(actions: [MacroAction]) {
        if HotkeyVoiceSessionPolicy.shouldCancelActiveVoice(
            activeActionID: VoiceActionRunner.shared.activeActionID,
            actions: actions,
            shortcutFor: KeyboardShortcuts.getShortcut
        ) {
            // Toggle mode has no pressed edge while recording, so latch cleanup
            // alone cannot stop a disabled/deleted/conflicting voice Action.
            VoiceActionRunner.shared.cancelBeforeUpload()
        }

        // Recorder and enabled-state changes can remove a physical registration
        // without delivering its final key-up. Never retain an orphaned edge.
        // Changing shortcut registration while a hold is physically down can
        // prevent the package from delivering its matching key-up. Cancel the
        // pre-upload voice session first, then clear every orphanable edge.
        if !pressed.isEmpty {
            VoiceActionRunner.shared.cancelBeforeUpload()
        }
        pressed.reset()
        for action in actions {
            bind(name: action.shortcutName, actionID: action.id)
        }

        KeyboardShortcuts.disable(actions.map(\.shortcutName))
        KeyboardShortcuts.enable(
            HotkeyRegistrationPolicy.namesToEnable(
                actions: actions,
                shortcutFor: KeyboardShortcuts.getShortcut
            )
        )
    }

    /// Disables and resets a deleted action's recorded key.
    ///
    /// The underlying callback remains registered in memory because the package
    /// cannot remove it; the shortcut name must never be assigned to another
    /// action in the same process.
    func unbind(name: KeyboardShortcuts.Name) {
        let key = name.rawValue
        if let press = pressed.finish(for: key),
           press.voiceMode != nil,
           VoiceActionRunner.shared.activeActionID == press.action.id {
            VoiceActionRunner.shared.cancelBeforeUpload()
        }
        KeyboardShortcuts.disable(name)
        KeyboardShortcuts.removeHandler(for: name)
        KeyboardShortcuts.reset(name)
        registered.remove(key)
    }
}

/// The subset of `HotkeyCoordinator` that `SettingsManager` drives. Extracted as a
/// protocol so tests can inject a no-op fake instead of registering real global
/// shortcuts (which need a login session).
@MainActor
protocol HotkeyBinding {
    func unbind(name: KeyboardShortcuts.Name)
    func reconcile(actions: [MacroAction])
}

extension HotkeyCoordinator: HotkeyBinding {}

/// One source of truth for whether a saved Action has a usable shortcut.
///
/// Views, setup readiness, Carbon registration, and the fire-time guard must all
/// agree that only *enabled* Actions participate in an internal conflict.
enum ActionShortcutPolicy {
    static func conflictingAction(
        for action: MacroAction,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> MacroAction? {
        guard action.isEnabled,
              let shortcut = shortcutFor(action.shortcutName) else { return nil }

        return actions.first { candidate in
            candidate.id != action.id
                && candidate.isEnabled
                && shortcutFor(candidate.shortcutName) == shortcut
        }
    }

    static func isRunnable(
        _ action: MacroAction,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> Bool {
        action.isEnabled
            && shortcutFor(action.shortcutName) != nil
            && conflictingAction(
                for: action,
                actions: actions,
                shortcutFor: shortcutFor
            ) == nil
    }

    static func hasRunnableAction(
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> Bool {
        actions.contains { action in
            isRunnable(action, actions: actions, shortcutFor: shortcutFor)
        }
    }
}

/// Selects only physically unique, enabled combinations for Carbon registration.
/// Conflicting Actions remain saved and visible in the editor, but the package
/// receives no live registration until the user resolves the conflict.
enum HotkeyRegistrationPolicy {
    static func namesToEnable(
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> [KeyboardShortcuts.Name] {
        actions.compactMap { action in
            ActionShortcutPolicy.isRunnable(
                action,
                actions: actions,
                shortcutFor: shortcutFor
            ) ? action.shortcutName : nil
        }
    }
}

/// Pure fire-time eligibility policy, kept separate from Carbon registration so
/// duplicate and nil-shortcut behavior can be unit-tested without installing a
/// real global shortcut.
enum HotkeyRunPolicy {
    static func runnableAction(
        actionID: UUID,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> MacroAction? {
        guard let action = actions.first(where: { $0.id == actionID }),
              ActionShortcutPolicy.isRunnable(
                action,
                actions: actions,
                shortcutFor: shortcutFor
              ) else { return nil }
        return action
    }
}

/// Reconciliation-time guard for an already recording voice Action.
///
/// Once upload begins `cancelBeforeUpload()` intentionally becomes a no-op;
/// changing settings then cannot truthfully promise that no audio was sent.
enum HotkeyVoiceSessionPolicy {
    static func shouldCancelActiveVoice(
        activeActionID: UUID?,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> Bool {
        guard let activeActionID else { return false }
        return HotkeyRunPolicy.runnableAction(
            actionID: activeActionID,
            actions: actions,
            shortcutFor: shortcutFor
        ) == nil
    }
}

/// Gives an existing session ownership priority over a live prompt edit.
/// Removing `{voice}` while toggle dictation is active must not turn the second
/// press into an ordinary Action run and strand the microphone.
enum HotkeyVoiceRoutePolicy {
    static func activationMode(
        for action: MacroAction,
        activeActionID: UUID?,
        activeActivationMode: VoiceActivationMode?,
        configuredActivationMode: VoiceActivationMode
    ) -> VoiceActivationMode? {
        if action.id == activeActionID {
            return activeActivationMode
        }
        return action.usesVoiceInput ? configuredActivationMode : nil
    }
}
