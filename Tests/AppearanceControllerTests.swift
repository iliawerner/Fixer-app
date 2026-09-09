import AppKit
import Testing
@testable import fixer

@MainActor
struct AppearanceControllerTests {
    @Test func startupAndLiveChangesApplySavedChoiceAndReleaseSystemOverride() throws {
        let suite = "fixer-appearance-controller-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = AppearancePreferences(defaults: defaults)
        preferences.appearance = .dark
        var appliedNames: [NSAppearance.Name?] = []
        let controller = AppearanceController(preferences: preferences) {
            appliedNames.append($0?.name)
        }
        #expect(appliedNames.isEmpty)

        controller.start()
        #expect(appliedNames == [.darkAqua])

        preferences.appearance = .light
        #expect(appliedNames == [.darkAqua, .aqua])

        preferences.appearance = .system
        #expect(appliedNames == [.darkAqua, .aqua, nil])
    }
}
