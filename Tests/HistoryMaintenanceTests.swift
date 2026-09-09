import Foundation
import Testing
@testable import fixer

@MainActor
struct HistoryMaintenanceTests {
    @Test
    func startupRetentionRemovesOnlyExpiredCompletedRuns() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-maintenance-\(UUID().uuidString)")
        let suite = "HistoryMaintenanceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expired = try #require(Calendar.current.date(byAdding: .day, value: -8, to: now))
        let boundary = try #require(Calendar.current.date(byAdding: .day, value: -7, to: now))
        let recent = try #require(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let oldSuccess = try seed(directory: directory, status: .succeeded, updatedAt: expired)
        let oldCancellation = try seed(directory: directory, status: .cancelled, updatedAt: expired)
        let oldFailure = try seed(directory: directory, status: .failed, updatedAt: expired)
        let oldInterruption = try seed(directory: directory, status: .interrupted, updatedAt: expired)
        let recentSuccess = try seed(directory: directory, status: .succeeded, updatedAt: recent)
        let boundarySuccess = try seed(directory: directory, status: .succeeded, updatedAt: boundary)
        let history = HistoryStore(directory: directory)
        let active = try history.begin(action: .dictation())
        let preferences = HistoryPreferences(defaults: defaults)
        preferences.retentionDays = 7

        try HistoryMaintenance.applyRetention(history: history, preferences: preferences, now: now)

        #expect(history.entry(id: oldSuccess) == nil)
        #expect(history.entry(id: oldCancellation) == nil)
        #expect(history.entry(id: oldFailure)?.status == .failed)
        #expect(history.entry(id: oldInterruption)?.status == .interrupted)
        #expect(history.entry(id: recentSuccess) != nil)
        #expect(history.entry(id: boundarySuccess) != nil)
        #expect(history.entry(id: active)?.isActive == true)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(oldSuccess.uuidString).path))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(oldCancellation.uuidString).path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(oldFailure.uuidString).path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(oldInterruption.uuidString).path))
    }

    @Test
    func foreverDoesNotPruneEvenVeryOldSuccessfulRuns() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-maintenance-\(UUID().uuidString)")
        let suite = "HistoryMaintenanceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let oldDate = Date(timeIntervalSince1970: 1)
        let success = try seed(directory: directory, status: .succeeded, updatedAt: oldDate)
        let cancelled = try seed(directory: directory, status: .cancelled, updatedAt: oldDate)
        let history = HistoryStore(directory: directory)
        let preferences = HistoryPreferences(defaults: defaults)
        preferences.retentionDays = 0

        try HistoryMaintenance.applyRetention(history: history, preferences: preferences)

        #expect(Set(history.entries.map(\.id)) == Set([success, cancelled]))
        #expect(history.persistenceError == nil)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(success.uuidString).path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(cancelled.uuidString).path))
    }

    /// Seed genuine on-disk snapshots so the startup test exercises reload and
    /// persisted dates, not a fake pruning method or the store's update clock.
    private func seed(directory: URL, status: HistoryStatus, updatedAt: Date) throws -> UUID {
        let entry = HistoryEntry(
            createdAt: updatedAt,
            updatedAt: updatedAt,
            action: .dictation(),
            sourceText: "Retained input",
            status: status
        )
        let entryDirectory = directory.appendingPathComponent(entry.id.uuidString)
        try FileManager.default.createDirectory(at: entryDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(entry).write(to: entryDirectory.appendingPathComponent("entry.json"), options: .atomic)
        return entry.id
    }
}
