import Foundation

/// Applies the same retention policy in ordinary launches and isolated QA.
@MainActor
enum HistoryMaintenance {
    static func applyRetention(
        history: HistoryStore,
        preferences: HistoryPreferences,
        now: Date = .now
    ) throws {
        guard preferences.retentionDays > 0,
              let cutoff = Calendar.current.date(byAdding: .day, value: -preferences.retentionDays, to: now) else {
            return
        }
        try history.prune(olderThan: cutoff)
    }
}
