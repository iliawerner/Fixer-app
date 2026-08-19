import Testing
import Foundation
import KeyboardShortcuts
@testable import fixer

/// A no-op stand-in for HotkeyCoordinator so tests never register real global
/// shortcuts (which need a login session).
@MainActor
final class FakeHotkeyBinding: HotkeyBinding {
    private(set) var unbound: [String] = []
    private(set) var reconciledActions: [[MacroAction]] = []

    func unbind(name: KeyboardShortcuts.Name) {
        unbound.append(name.rawValue)
    }

    func reconcile(actions: [MacroAction]) {
        reconciledActions.append(actions)
    }
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

    @Test func addingAnActionReconcilesTheCompleteSnapshot() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        let newID = mgr.addAction()

        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.count == 2)
        #expect(snapshot.contains { $0.id == newID })
    }

    @Test func recorderChangeReconcilesWithoutUsingTheGlobalCoordinator() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)

        mgr.reconcileShortcuts()

        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.map(\.id) == mgr.actions.map(\.id))
    }

    @Test func enabledStateReconcilesTheUpdatedAction() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        let id = try #require(mgr.actions.first?.id)

        mgr.setEnabled(false, id: id)

        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.first(where: { $0.id == id })?.isEnabled == false)
    }

    @Test func deletingReconcilesSurvivorsAfterRetiringTheName() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        let deletedName = try #require(mgr.actions.first?.shortcutName.rawValue)
        let survivorID = mgr.addAction()

        mgr.deleteAction(id: try #require(mgr.actions.first?.id))

        #expect(fake.unbound.contains(deletedName))
        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.map(\.id) == [survivorID])
    }
}
