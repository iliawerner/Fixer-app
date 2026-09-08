import Foundation
import Combine

/// Each entry has its own atomically replaced JSON record and private audio
/// directory. A damaged record never prevents loading the rest of the history.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var persistenceError: String?

    let directory: URL
    private let files = FileManager.default
    private var errors: [String: String] = [:]

    /// Failed reads have no row, but an explicit clear must still be available
    /// for their retained UUID directories. Generic directory errors do not count.
    var hasClearableEntries: Bool {
        entries.contains { !$0.isActive } || errors.keys.contains { key in
            guard let id = UUID(uuidString: key) else { return false }
            return entry(id: id) == nil
        }
    }

    init(directory: URL? = nil) {
        self.directory = directory ?? PersistenceEnvironment.historyDirectory()
        load()
    }

    func begin(action: MacroAction, sourceAppName: String? = nil, sourceText: String = "") throws -> UUID {
        let entry = HistoryEntry(action: action, sourceAppName: sourceAppName, sourceText: sourceText)
        // Retain the source even if the disk is full. The caller reports the
        // persistence failure and must not proceed with a destructive delivery.
        entries.insert(entry, at: 0)
        do {
            try persistReporting(entry)
        } catch {
            entries[0].status = .failed
            entries[0].errorMessage = "History could not save this operation. \(error.localizedDescription)"
            throw error
        }
        return entry.id
    }

    func update(_ id: UUID, _ edit: (inout HistoryEntry) -> Void) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw HistoryStoreError.missingEntry
        }
        var changed = entries[index]
        edit(&changed)
        guard changed.id == id else { throw HistoryStoreError.changedIdentity }
        changed.updatedAt = .now
        entries[index] = changed
        try persistReporting(changed)
    }

    func entry(id: UUID) -> HistoryEntry? {
        entries.first { $0.id == id }
    }

    /// Commits the WAV before changing metadata. A prior incremental recording
    /// is removed only after the metadata replacement also succeeds.
    func saveAudio(_ audio: VoiceAudio, for id: UUID) throws {
        guard let previous = entry(id: id) else { throw HistoryStoreError.missingEntry }
        guard audio.duration.isFinite, audio.duration >= 0,
              ["audio/wav", "audio/x-wav", "audio/wave"].contains(audio.mimeType),
              Self.hasAudioHeader(audio.data, extension: "wav") else {
            throw HistoryStoreError.invalidAudio
        }
        let name = "audio-\(UUID().uuidString).wav"
        let url = entryDirectory(id).appendingPathComponent(name)
        do {
            try createEntryDirectory(id)
            try writePrivate(audio.data, to: url)
            try update(id) {
                $0.audioFileName = name
                $0.audioDuration = audio.duration
            }
            if let oldName = previous.audioFileName, oldName != name,
               let oldURL = safeAudioURL(name: oldName, id: id), files.fileExists(atPath: oldURL.path) {
                try files.removeItem(at: oldURL)
            }
        } catch {
            report(error, key: id.uuidString)
            throw error
        }
    }

    /// Registers the recovery path before microphone capture starts. The capture
    /// layer writes a CAF to this path incrementally and closes it on every exit.
    func prepareRecording(for id: UUID) throws -> URL {
        guard entry(id: id) != nil else { throw HistoryStoreError.missingEntry }
        let name = "recording-\(UUID().uuidString).caf"
        do {
            try createEntryDirectory(id)
            try update(id) { $0.audioFileName = name }
            return entryDirectory(id).appendingPathComponent(name)
        } catch {
            report(error, key: id.uuidString)
            throw error
        }
    }

    func audioURL(for entry: HistoryEntry) -> URL? {
        guard let name = entry.audioFileName,
              let url = safeAudioURL(name: name, id: entry.id),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              (values.fileSize ?? 0) > 12,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 12),
              Self.hasAudioHeader(header, extension: url.pathExtension) else { return nil }
        return url
    }

    func delete(_ id: UUID) throws {
        guard let entry = entry(id: id) else { throw HistoryStoreError.missingEntry }
        guard !entry.isActive else { throw HistoryStoreError.activeEntry }
        do {
            let url = entryDirectory(id)
            if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
            entries.removeAll { $0.id == id }
            errors.removeValue(forKey: id.uuidString)
            refreshError()
        } catch {
            report(error, key: id.uuidString)
            throw error
        }
    }

    /// User-requested clearing includes failed operations, but never an active
    /// recording or request. Corrupt UUID records are removed only by this
    /// explicit action, never by loading or retention pruning.
    func clear() throws {
        var firstError: Error?
        do { try remove(entries.filter { !$0.isActive }.map(\.id)) }
        catch { firstError = error }

        if files.fileExists(atPath: directory.path) {
            do {
                let children = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                for child in children {
                    guard let id = UUID(uuidString: child.lastPathComponent),
                          entry(id: id) == nil else { continue }
                    do {
                        // removeItem removes a symbolic link itself; it does not
                        // traverse its destination. Active IDs are excluded above.
                        try files.removeItem(at: child)
                        errors.removeValue(forKey: id.uuidString)
                    } catch {
                        report(error, key: id.uuidString)
                        if firstError == nil { firstError = error }
                    }
                }
                errors.removeValue(forKey: "directory")
            } catch {
                report(error, key: "directory")
                if firstError == nil { firstError = error }
            }
        }
        refreshError()
        if let firstError { throw firstError }
    }

    func prune(olderThan cutoff: Date) throws {
        try remove(entries.filter {
            ($0.status == .succeeded || $0.status == .cancelled) && $0.updatedAt < cutoff
        }.map(\.id))
    }

    private func remove(_ ids: [UUID]) throws {
        var firstError: Error?
        for id in ids {
            do { try delete(id) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }

    private func entryDirectory(_ id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func createEntryDirectory(_ id: UUID) throws {
        try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        try files.createDirectory(at: entryDirectory(id), withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
    }

    private func writePrivate(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func persistReporting(_ entry: HistoryEntry) throws {
        do {
            try createEntryDirectory(entry.id)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(entry)
            try writePrivate(data, to: entryDirectory(entry.id).appendingPathComponent("entry.json"))
            errors.removeValue(forKey: entry.id.uuidString)
            refreshError()
        } catch {
            report(error, key: entry.id.uuidString)
            throw error
        }
    }

    private func load() {
        guard files.fileExists(atPath: directory.path) else { return }
        do {
            let children = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey])
            for child in children {
                guard let id = UUID(uuidString: child.lastPathComponent) else { continue }
                do {
                    guard try child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                        throw HistoryStoreError.invalidRecord
                    }
                    let data = try Data(contentsOf: child.appendingPathComponent("entry.json"))
                    var entry = try JSONDecoder().decode(HistoryEntry.self, from: data)
                    guard entry.id == id else { throw HistoryStoreError.invalidRecord }
                    if entry.isActive {
                        entry.status = .interrupted
                        entry.updatedAt = .now
                        entry.errorMessage = "Fixer closed before this operation finished. Saved source material is available in History."
                        entries.append(entry)
                        try persistReporting(entry)
                    } else {
                        entries.append(entry)
                    }
                } catch {
                    report(error, key: id.uuidString)
                }
            }
            entries.sort { $0.createdAt > $1.createdAt }
        } catch {
            report(error, key: "directory")
        }
    }

    private func safeAudioURL(name: String, id: UUID) -> URL? {
        guard name == URL(fileURLWithPath: name).lastPathComponent,
              !name.contains("/"), !name.contains("\\"),
              ["wav", "caf"].contains(URL(fileURLWithPath: name).pathExtension.lowercased()) else { return nil }
        return entryDirectory(id).appendingPathComponent(name)
    }

    private static func hasAudioHeader(_ data: Data, extension suffix: String) -> Bool {
        guard data.count >= 12 else { return false }
        switch suffix.lowercased() {
        case "wav":
            return data.prefix(4) == Data("RIFF".utf8) && data.dropFirst(8).prefix(4) == Data("WAVE".utf8)
        case "caf":
            return data.prefix(4) == Data("caff".utf8)
        default:
            return false
        }
    }

    private func report(_ error: Error, key: String) {
        errors[key] = error.localizedDescription
        refreshError()
    }

    private func refreshError() {
        guard !errors.isEmpty else { persistenceError = nil; return }
        let details = errors.values.sorted().first ?? "Unknown storage error."
        persistenceError = "History could not save or read \(errors.count) item(s). Available material is kept in memory; unreadable files are preserved. \(details)"
    }
}
