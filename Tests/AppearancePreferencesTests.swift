import Foundation
import Testing
@testable import fixer

@MainActor
struct AppearancePreferencesTests {
    @Test func newInstallFollowsSystemWithoutWritingAnOverride() throws {
        let suite = "fixer-appearance-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = AppearancePreferences(defaults: defaults)

        #expect(preferences.appearance == .system)
        #expect(defaults.object(forKey: AppearancePreferences.storageKey) == nil)
    }

    @Test(arguments: AppAppearance.allCases)
    func eachChoiceSurvivesRelaunch(appearance: AppAppearance) throws {
        let suite = "fixer-appearance-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = AppearancePreferences(defaults: defaults)
        preferences.appearance = appearance
        let restored = AppearancePreferences(defaults: defaults)

        #expect(restored.appearance == appearance)
        #expect(defaults.string(forKey: AppearancePreferences.storageKey) == appearance.rawValue)
    }

    @Test func unknownOrMalformedChoiceFallsBackToSystemAndCanBeReplaced() throws {
        let suite = "fixer-appearance-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("unrecognized-theme", forKey: AppearancePreferences.storageKey)
        #expect(AppearancePreferences(defaults: defaults).appearance == .system)

        defaults.set(["unexpected": true], forKey: AppearancePreferences.storageKey)
        let preferences = AppearancePreferences(defaults: defaults)
        #expect(preferences.appearance == .system)

        preferences.appearance = .dark
        #expect(AppearancePreferences(defaults: defaults).appearance == .dark)
    }

    @Test func injectedStoresRemainIndependent() throws {
        let firstSuite = "fixer-appearance-test-\(UUID().uuidString)"
        let secondSuite = "fixer-appearance-test-\(UUID().uuidString)"
        let firstDefaults = try #require(UserDefaults(suiteName: firstSuite))
        let secondDefaults = try #require(UserDefaults(suiteName: secondSuite))
        defer {
            firstDefaults.removePersistentDomain(forName: firstSuite)
            secondDefaults.removePersistentDomain(forName: secondSuite)
        }

        AppearancePreferences(defaults: firstDefaults).appearance = .dark

        #expect(AppearancePreferences(defaults: firstDefaults).appearance == .dark)
        #expect(AppearancePreferences(defaults: secondDefaults).appearance == .system)
    }
}
