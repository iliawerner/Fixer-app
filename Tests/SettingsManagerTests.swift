import Testing
import Foundation
import KeyboardShortcuts
@testable import fixer

/// A no-op stand-in for HotkeyCoordinator so tests never register real global
/// shortcuts (which need a login session).
@MainActor
final class FakeHotkeyBinding: HotkeyBinding {
    private(set) var bound: [String] = []
    func bind(name: KeyboardShortcuts.Name, actionID: UUID) { bound.append(name.rawValue) }
    func unbind(name: KeyboardShortcuts.Name) { bound.removeAll { $0 == name.rawValue } }
    func setEnabled(_ enabled: Bool, name: KeyboardShortcuts.Name) {}
}

@MainActor
struct SettingsManagerTests {

    /// A private, empty UserDefaults suite so tests don't touch real preferences.
    private func freshDefaults() -> UserDefaults {
        let suite = "fixer-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func seedsDefaultActionOnFirstLaunch() {
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: FakeHotkeyBinding())
        #expect(mgr.actions.count == 1)
        #expect(mgr.actions[0].name == "Fix grammar")
    }

    @Test func persistsAcrossInstances() {
        let defaults = freshDefaults()
        let mgr = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        mgr.addAction()
        #expect(mgr.actions.count == 2)

        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.actions.count == 2)
    }

    @Test func duplicateGetsNewIDNameAndShortcut() {
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: FakeHotkeyBinding())
        let srcID = mgr.actions[0].id

        let newID = mgr.duplicate(id: srcID)

        #expect(newID != nil)
        #expect(newID != srcID)
        #expect(mgr.actions.count == 2)
        #expect(mgr.actions[1].name == "Fix grammar copy")
        #expect(mgr.actions[1].shortcutName.rawValue != mgr.actions[0].shortcutName.rawValue)
    }

    /// Pins the intentional behavior: deleting every action reseeds the default on
    /// next load (an empty saved array is treated as "no data").
    @Test func deletingAllReseedsDefaultOnReload() {
        let defaults = freshDefaults()
        let mgr = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        for action in mgr.actions { mgr.deleteAction(id: action.id) }
        #expect(mgr.actions.isEmpty)

        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.actions.count == 1)
        #expect(reloaded.actions[0].name == "Fix grammar")
    }

    @Test func addingAnActionBindsItsShortcut() {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        mgr.addAction()
        #expect(fake.bound.count == 1)
    }
}
