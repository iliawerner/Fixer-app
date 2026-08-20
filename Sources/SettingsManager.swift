import Foundation
import SwiftUI
import KeyboardShortcuts

/// Main-actor store for the user's actions and their shortcut lifecycle.
///
/// The action array is persisted as one JSON value in UserDefaults after every
/// mutation. Creation, duplication, deletion, Recorder changes, and enabled-state
/// changes are also reconciled through `HotkeyBinding`, keeping persistence and
/// global-shortcut state in one ownership boundary.
@MainActor
final class SettingsManager: ObservableObject {
    // MARK: - Shared store

    static let shared = SettingsManager()

    /// The source of truth for saved actions. Mutations, including edits through
    /// a binding to an array element, trigger immediate JSON persistence.
    @Published var actions: [MacroAction] = [] {
        didSet { saveActions() }
    }

    // MARK: - Dependencies and persistence identity

    private let defaults: UserDefaults
    /// Compatibility key inside the app's pinned UserDefaults domain.
    private let actionsKey = "savedActions"
    private let hotkeys: HotkeyBinding

    /// Creates an action store and immediately loads its persisted snapshot.
    ///
    /// - Parameters:
    ///   - defaults: persistence store (inject `UserDefaults(suiteName:)` in tests).
    ///   - hotkeys: the shortcut binder (inject a fake in tests so no real global
    ///     shortcuts are registered).
    init(defaults: UserDefaults = .standard, hotkeys: HotkeyBinding? = nil) {
        self.defaults = defaults
        self.hotkeys = hotkeys ?? HotkeyCoordinator.shared
        loadActions()
    }

    // MARK: - Mutations

    /// Adds a blank action, reconciles its fresh shortcut identity, and returns
    /// the action id so the workspace can select it.
    @discardableResult
    func addAction() -> UUID {
        // Each action gets a brand-new random shortcut Name. These are single-use
        // (see HotkeyCoordinator): a Name is never reused, so a fresh UUID here — in
        // addStarter and duplicate too — avoids colliding with a retired handler.
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let action = MacroAction(name: "New action", shortcutName: newName)
        actions.append(action)
        hotkeys.reconcile(actions: actions)
        return action.id
    }

    /// Copies a curated starter into the user's persistent action collection.
    @discardableResult
    func addStarter(_ starter: StarterAction) -> UUID {
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let action = MacroAction(name: starter.name,
                                 shortcutName: newName,
                                 promptTemplate: starter.prompt,
                                 modelName: defaultModelName,
                                 outputMode: starter.mode)
        actions.append(action)
        hotkeys.reconcile(actions: actions)
        return action.id
    }

    /// Duplicates an action's editable fields while assigning new action and
    /// shortcut identities.
    @discardableResult
    func duplicate(id: UUID) -> UUID? {
        guard let source = actions.first(where: { $0.id == id }),
              source.kind == .text else { return nil }
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let copy = MacroAction(name: source.name + " copy",
                               shortcutName: newName,
                               promptTemplate: source.promptTemplate,
                               modelName: source.modelName,
                               outputMode: source.outputMode,
                               isEnabled: source.isEnabled)
        actions.append(copy)
        hotkeys.reconcile(actions: actions)
        return copy.id
    }

    /// Deletes an action and retires its shortcut identity before removing the
    /// persisted value.
    func deleteAction(id: UUID) {
        guard let index = actions.firstIndex(where: { $0.id == id }),
              actions[index].kind == .text else { return }
        hotkeys.unbind(name: actions[index].shortcutName)
        actions.remove(at: index)
        // `reset` unregisters the physical combination even when another saved
        // Name shares it, so restore the surviving Actions immediately.
        hotkeys.reconcile(actions: actions)
    }

    /// Enables or disables delivery without erasing the user's recorded key.
    func setEnabled(_ enabled: Bool, id: UUID) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index].isEnabled = enabled
        hotkeys.reconcile(actions: actions)
    }

    /// Updates the one process-wide voice gesture stored by the built-in
    /// Dictation Action. Voice-enabled text Actions read this setting at fire
    /// time, so no shortcut handler needs to be rebound when it changes.
    func setVoiceActivationMode(_ mode: VoiceActivationMode) {
        guard let index = actions.firstIndex(where: { $0.kind == .dictation }) else {
            return
        }
        actions[index].voiceActivationMode = mode
    }

    var voiceActivationMode: VoiceActivationMode {
        actions.first(where: { $0.kind == .dictation })?.voiceActivationMode ?? .toggle
    }

    /// Reconciles the complete shortcut set after KeyboardShortcuts.Recorder has
    /// already persisted its change in the package's UserDefaults namespace.
    /// The UI calls this ownership boundary instead of reaching for the global
    /// coordinator directly.
    func reconcileShortcuts() {
        hotkeys.reconcile(actions: actions)
    }

    // MARK: - Persistence

    private func saveActions() {
        // An encoding failure leaves the last successfully stored snapshot intact;
        // the current implementation has no user-facing persistence-error channel.
        if let encoded = try? JSONEncoder().encode(actions) {
            defaults.set(encoded, forKey: actionsKey)
        }
    }

    private func loadActions() {
        // Older builds have no Dictation entry. Normalize every decoded snapshot
        // through one migration seam so the permanent Action appears exactly once
        // and always remains pinned first without touching the user's text Actions.
        if let data = defaults.data(forKey: actionsKey),
           let decoded = try? JSONDecoder().decode([MacroAction].self, from: data) {
            self.actions = Self.normalizedActions(decoded)
        } else {
            let defaultName = KeyboardShortcuts.Name("defaultAction")
            let action = MacroAction(name: "Fix grammar",
                                     shortcutName: defaultName,
                                     promptTemplate: "Fix grammar and make it sound simple and natural: {text}. Return only the corrected text.",
                                     modelName: defaultModelName,
                                     outputMode: .replace)
            self.actions = [MacroAction.dictation(), action]
        }

        // Persist the migration immediately. Otherwise an untouched legacy store
        // would repeat normalization on every launch until the first UI edit.
        saveActions()
    }

    nonisolated static func normalizedActions(_ decoded: [MacroAction]) -> [MacroAction] {
        let persistedDictation = decoded.first {
            $0.kind == .dictation || $0.id == MacroAction.dictationID
        }
        let dictation = MacroAction.dictation(
            isEnabled: persistedDictation?.isEnabled ?? true,
            activationMode: persistedDictation?.voiceActivationMode ?? .toggle
        )
        let textActions = decoded.filter {
            $0.kind == .text && $0.id != MacroAction.dictationID
        }
        return [dictation] + textActions
    }
}
