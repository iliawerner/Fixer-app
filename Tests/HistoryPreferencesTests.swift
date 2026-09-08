import Testing
import Foundation
@testable import fixer

@MainActor
struct HistoryPreferencesTests {
    @Test func fallbackCopyDefaultsOnAndCanBeDisabledPersistently() throws {
        let suite = "fixer-history-preferences-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = HistoryPreferences(defaults: defaults)
        #expect(preferences.copyResultWhenTargetChanges)
        #expect(preferences.retentionDays == 30)
        preferences.copyResultWhenTargetChanges = false
        preferences.retentionDays = 0
        let restored = HistoryPreferences(defaults: defaults)
        #expect(!restored.copyResultWhenTargetChanges)
        #expect(restored.retentionDays == 0)
    }
}
