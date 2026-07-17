import Foundation
import SwiftUI
import KeyboardShortcuts

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var actions: [MacroAction] = [] {
        didSet { saveActions() }
    }

    private let defaults = UserDefaults.standard
    private let actionsKey = "savedActions"

    private init() {
        loadActions()
    }

    @discardableResult
    func addAction() -> UUID {
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let action = MacroAction(name: "New action", shortcutName: newName)
        actions.append(action)
        HotkeyCoordinator.shared.bind(name: action.shortcutName, actionID: action.id)
        return action.id
    }

    @discardableResult
    func addStarter(_ starter: StarterAction) -> UUID {
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let action = MacroAction(name: starter.name,
                                 shortcutName: newName,
                                 promptTemplate: starter.prompt,
                                 modelName: defaultModelName,
                                 outputMode: starter.mode)
        actions.append(action)
        HotkeyCoordinator.shared.bind(name: action.shortcutName, actionID: action.id)
        return action.id
    }

    @discardableResult
    func duplicate(id: UUID) -> UUID? {
        guard let source = actions.first(where: { $0.id == id }) else { return nil }
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let copy = MacroAction(name: source.name + " copy",
                               shortcutName: newName,
                               promptTemplate: source.promptTemplate,
                               modelName: source.modelName,
                               outputMode: source.outputMode,
                               isEnabled: source.isEnabled)
        actions.append(copy)
        HotkeyCoordinator.shared.bind(name: copy.shortcutName, actionID: copy.id)
        return copy.id
    }

    func deleteAction(id: UUID) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        HotkeyCoordinator.shared.unbind(name: actions[index].shortcutName)
        actions.remove(at: index)
    }

    func setEnabled(_ enabled: Bool, id: UUID) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index].isEnabled = enabled
        HotkeyCoordinator.shared.setEnabled(enabled, name: actions[index].shortcutName)
    }

    private func saveActions() {
        if let encoded = try? JSONEncoder().encode(actions) {
            defaults.set(encoded, forKey: actionsKey)
        }
    }

    private func loadActions() {
        if let data = defaults.data(forKey: actionsKey),
           let decoded = try? JSONDecoder().decode([MacroAction].self, from: data),
           !decoded.isEmpty {
            self.actions = decoded
        } else {
            let defaultName = KeyboardShortcuts.Name("defaultAction")
            let action = MacroAction(name: "Fix grammar",
                                     shortcutName: defaultName,
                                     promptTemplate: "Fix grammar and make it sound simple and natural: {text}. Return only the corrected text.",
                                     modelName: defaultModelName,
                                     outputMode: .replace)
            self.actions = [action]
        }
    }
}
