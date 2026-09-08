import Testing
import Foundation
import KeyboardShortcuts
@testable import fixer

@MainActor
struct HistoryStoreTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixer-history-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func action() -> MacroAction {
        MacroAction(name: "Saved action", shortcutName: .init(UUID().uuidString), promptTemplate: "Fix {text}")
    }

    private func wav() throws -> VoiceAudio {
        VoiceAudio(data: try WAVAudioEncoder.encodeMonoPCM16(samples: [0, 0.1, -0.2], sourceSampleRate: 16_000),
                   mimeType: "audio/wav", duration: 0.1)
    }

    @Test func storesCompleteSnapshotAndRestoresInterruptedOperation() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let savedAction = action()
        let id = try store.begin(action: savedAction, sourceAppName: "TextEdit", sourceText: "Original")
        try store.update(id) {
            $0.transcript = "Spoken text"
            $0.transcriptionModelName = "models/speech-model"
            $0.prompt = "Exact submitted prompt"
            $0.result = "Partial result"
            $0.stage = .generation
        }

        let reloaded = HistoryStore(directory: directory)
        let restored = try #require(reloaded.entry(id: id))
        #expect(restored.action == savedAction)
        #expect(restored.sourceAppName == "TextEdit")
        #expect(restored.sourceText == "Original")
        #expect(restored.transcript == "Spoken text")
        #expect(restored.transcriptionModelName == "models/speech-model")
        #expect(restored.prompt == "Exact submitted prompt")
        #expect(restored.result == "Partial result")
        #expect(restored.stage == .generation)
        #expect(restored.status == .interrupted)
        #expect(restored.errorMessage != nil)
        #expect(HistoryStore(directory: directory).entry(id: id)?.status == .interrupted)
    }

    @Test func oldRecordWithoutTranscriptionModelStillDecodes() throws {
        let entry = HistoryEntry(action: action(), transcript: "Preserved transcript")
        let data = try JSONEncoder().encode(entry)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "transcriptionModelName")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: oldData)
        #expect(decoded.transcriptionModelName == nil)
        #expect(decoded.transcript == "Preserved transcript")
    }

    @Test func corruptRecordDoesNotDiscardOtherRecordsOrGetOverwritten() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let goodID = try store.begin(action: action(), sourceText: "Keep me")
        try store.update(goodID) { $0.status = .succeeded }
        let badID = try store.begin(action: action())
        let damagedURL = directory.appendingPathComponent(badID.uuidString).appendingPathComponent("entry.json")
        let badData = Data("truncated {".utf8)
        try badData.write(to: damagedURL)

        let reloaded = HistoryStore(directory: directory)
        #expect(reloaded.entries.map(\.id) == [goodID])
        #expect(reloaded.persistenceError != nil)
        #expect(try Data(contentsOf: damagedURL) == badData)
        try reloaded.update(goodID) { $0.result = "Updated" }
        #expect(reloaded.persistenceError != nil)
    }

    @Test func updateFailureRetainsNewMaterialInMemory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let id = try store.begin(action: action(), sourceText: "Original")
        let record = directory.appendingPathComponent(id.uuidString).appendingPathComponent("entry.json")
        try FileManager.default.removeItem(at: record)
        try FileManager.default.createDirectory(at: record, withIntermediateDirectories: false)

        #expect(throws: (any Error).self) {
            try store.update(id) { $0.result = "Never lose this result" }
        }
        #expect(store.entry(id: id)?.sourceText == "Original")
        #expect(store.entry(id: id)?.result == "Never lose this result")
        #expect(store.persistenceError != nil)

        try FileManager.default.removeItem(at: record)
        try store.update(id) { $0.status = .failed }
        #expect(store.persistenceError == nil)
        #expect(HistoryStore(directory: directory).entry(id: id)?.result == "Never lose this result")
    }

    @Test func beginFailureRetainsSourceInAFailedEntry() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blocker)
        let store = HistoryStore(directory: blocker)
        #expect(throws: (any Error).self) {
            try store.begin(action: action(), sourceText: "Unprocessed source")
        }
        #expect(store.entries.first?.sourceText == "Unprocessed source")
        #expect(store.entries.first?.status == .failed)
        #expect(store.persistenceError != nil)
    }

    @Test func activeEntriesCannotBeDeletedAndClearKeepsThem() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let activeID = try store.begin(action: action())
        let failedID = try store.begin(action: action())
        try store.update(failedID) { $0.status = .failed }

        #expect(throws: HistoryStoreError.self) { try store.delete(activeID) }
        try store.clear()
        #expect(store.entries.map(\.id) == [activeID])
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(failedID.uuidString).path))
    }

    @Test func pruningOnlyRemovesOldSuccessfulOrCancelledEntries() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        var retained: [UUID] = []
        for status in [HistoryStatus.running, .failed, .interrupted, .succeeded, .cancelled] {
            let id = try store.begin(action: action())
            try store.update(id) { $0.status = status }
            if [.running, .failed, .interrupted].contains(status) { retained.append(id) }
        }
        try store.prune(olderThan: .now.addingTimeInterval(1))
        #expect(Set(store.entries.map(\.id)) == Set(retained))
    }

    @Test func explicitClearRemovesCorruptRecordsButProtectsActiveAndSymlinkDestination() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let damagedDirectory = directory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: damagedDirectory, withIntermediateDirectories: false)
        try Data("broken".utf8).write(to: damagedDirectory.appendingPathComponent("entry.json"))
        let outside = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: outside) }
        let outsideData = outside.appendingPathComponent("preserve.wav")
        try wav().data.write(to: outsideData)
        let linkedDirectory = directory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: outside)
        let store = HistoryStore(directory: directory)
        #expect(store.persistenceError != nil)
        #expect(store.entries.isEmpty)
        #expect(store.hasClearableEntries)
        let activeID = try store.begin(action: action(), sourceText: "Still running")

        try store.clear()

        #expect(store.entries.map(\.id) == [activeID])
        #expect(store.persistenceError == nil)
        #expect(!store.hasClearableEntries)
        #expect(!FileManager.default.fileExists(atPath: damagedDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: linkedDirectory.path))
        #expect(FileManager.default.fileExists(atPath: outsideData.path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(activeID.uuidString).path))
    }

    @Test func completedWAVReplacesRecoveryAudioOnlyAfterMetadataCommit() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let id = try store.begin(action: .dictation())
        let recoveryURL = try store.prepareRecording(for: id)
        #expect(store.entry(id: id)?.audioFileName == recoveryURL.lastPathComponent)
        let recordingEntry = try #require(store.entry(id: id))
        #expect(store.audioURL(for: recordingEntry) == nil)
        try Data("caffabcdefghijklmnop".utf8).write(to: recoveryURL)
        #expect(store.audioURL(for: recordingEntry) == recoveryURL)
        let recording = try wav()
        try store.saveAudio(recording, for: id)

        let entry = try #require(store.entry(id: id))
        let audioURL = try #require(store.audioURL(for: entry))
        #expect(audioURL.pathExtension == "wav")
        #expect(try Data(contentsOf: audioURL) == recording.data)
        #expect(entry.audioDuration == recording.duration)
        #expect(!FileManager.default.fileExists(atPath: recoveryURL.path))
        #expect(HistoryStore(directory: directory).entry(id: id)?.audioFileName == entry.audioFileName)
    }

    @Test func failedWAVMetadataCommitPreservesRecoveryAndNewAudio() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let id = try store.begin(action: .dictation())
        let recoveryURL = try store.prepareRecording(for: id)
        try Data("caffabcdefghijklmnop".utf8).write(to: recoveryURL)
        let record = directory.appendingPathComponent(id.uuidString).appendingPathComponent("entry.json")
        try FileManager.default.removeItem(at: record)
        try FileManager.default.createDirectory(at: record, withIntermediateDirectories: false)

        #expect(throws: (any Error).self) { try store.saveAudio(wav(), for: id) }
        #expect(FileManager.default.fileExists(atPath: recoveryURL.path))
        let inMemory = try #require(store.entry(id: id))
        #expect(store.audioURL(for: inMemory)?.pathExtension == "wav")
        #expect(store.persistenceError != nil)
    }

    @Test func audioLookupRejectsTraversalAndSymbolicLinks() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let id = try store.begin(action: .dictation())
        var entry = try #require(store.entry(id: id))
        entry.audioFileName = "../../outside.wav"
        #expect(store.audioURL(for: entry) == nil)
        let outside = directory.appendingPathComponent("outside.wav")
        try wav().data.write(to: outside)
        let linked = directory.appendingPathComponent(id.uuidString).appendingPathComponent("linked.wav")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)
        entry.audioFileName = "linked.wav"
        #expect(store.audioURL(for: entry) == nil)
    }

    @Test func deletionRemovesRecordingAndMetadataTogether() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let id = try store.begin(action: .dictation())
        try store.saveAudio(wav(), for: id)
        try store.update(id) { $0.status = .failed }
        try store.delete(id)
        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(id.uuidString).path))
    }

    @Test func recordsAndAudioHavePrivatePermissions() throws {
        let directory = try temporaryDirectory().appendingPathComponent("History")
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let store = HistoryStore(directory: directory)
        let id = try store.begin(action: .dictation())
        try store.saveAudio(wav(), for: id)
        let record = directory.appendingPathComponent(id.uuidString).appendingPathComponent("entry.json")
        let entry = try #require(store.entry(id: id))
        let audio = try #require(store.audioURL(for: entry))
        for url in [record, audio] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
    }
}
