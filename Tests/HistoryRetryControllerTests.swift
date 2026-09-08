import Foundation
import Testing
@testable import fixer

@MainActor
struct HistoryRetryControllerTests {
    @Test func retryReusesTranscriptAndActionSnapshotWithoutTranscribingAgain() async throws {
        let fixture = RetryHistoryFixture()
        defer { fixture.removeFiles() }
        let action = MacroAction(name: "Voice edit", shortcutName: .init("retryVoice"),
                                 promptTemplate: "Rewrite {text}: {voice}", outputMode: .append)
        let originalID = try fixture.history.begin(action: action, sourceAppName: "Original app", sourceText: "source")
        try fixture.history.update(originalID) {
            $0.transcript = "instruction"
            $0.status = .failed
            $0.stage = .generation
        }
        let original = try #require(fixture.history.entry(id: originalID))
        let retry = fixture.controller(generate: { model, prompt in
            #expect(model == action.modelName)
            #expect(prompt == "Rewrite source: instruction")
            let newest = try fixture.diskEntry()
            #expect(newest.transcript == "instruction")
            #expect(newest.prompt == prompt)
            #expect(newest.stage == .generation)
            return "updated"
        })
        let task = try #require(retry.retry(original))
        #expect(retry.retry(original) == nil)
        await task.value
        #expect(fixture.history.entries.count == 2)
        #expect(fixture.history.entry(id: originalID) == original)
        #expect(try fixture.diskEntry().result == "source\nupdated")
        #expect(try fixture.diskEntry().status == .succeeded)
        #expect(fixture.deliveries == ["source\nupdated"])
        #expect(!fixture.state.isProcessing && !retry.isRetrying)
    }

    @Test func textRetryUsesSavedPromptAndFailureKeepsBothRecords() async throws {
        let fixture = RetryHistoryFixture()
        defer { fixture.removeFiles() }
        let originalID = try fixture.history.begin(action: .init(shortcutName: .init("retryText")), sourceText: "source")
        try fixture.history.update(originalID) { $0.prompt = "saved exact prompt"; $0.status = .failed }
        let original = try #require(fixture.history.entry(id: originalID))
        let retry = fixture.controller(generate: { _, prompt in
            #expect(prompt == "saved exact prompt")
            throw GeminiAPI.APIError.incompleteResponse("partial")
        })
        await retry.retry(original)?.value
        let newest = try fixture.diskEntry()
        #expect(newest.id != originalID)
        #expect(newest.sourceText == "source")
        #expect(newest.result == "partial")
        #expect(newest.status == .failed)
        #expect(fixture.history.entry(id: originalID) == original)
        #expect(fixture.deliveries.isEmpty)
    }

    @Test func recordingRetryStoresAudioBeforeRecognitionAndNeverRegeneratesDictation() async throws {
        let fixture = RetryHistoryFixture()
        defer { fixture.removeFiles() }
        let originalID = try fixture.history.begin(action: .dictation())
        let audio = VoiceAudio(data: try WAVAudioEncoder.encodeMonoPCM16(samples: .init(repeating: 0.1, count: 1600),
                                                                        sourceSampleRate: 16000), mimeType: "audio/wav", duration: 0.1)
        try fixture.history.saveAudio(audio, for: originalID)
        try fixture.history.update(originalID) { $0.status = .failed; $0.stage = .transcription }
        let original = try #require(fixture.history.entry(id: originalID))
        let retry = fixture.controller(transcribe: { input in
            #expect(input.duration == 0.1)
            let newest = try fixture.diskEntry()
            #expect(newest.id != originalID)
            #expect(newest.stage == .transcription)
            #expect(newest.transcriptionModelName == VoiceTranscriptionPolicy.modelID)
            #expect(fixture.history.audioURL(for: newest) != nil)
            return "recognized"
        }, generate: { _, _ in Issue.record("Pure dictation must not generate again"); return "unexpected" })
        await retry.retry(original)?.value
        #expect(try fixture.diskEntry().transcript == "recognized")
        #expect(try fixture.diskEntry().result == "recognized")
        #expect(fixture.history.audioURL(for: original) != nil)
    }

    @Test func missingRecordingLeavesRecoverableFailedAttempt() async throws {
        let fixture = RetryHistoryFixture()
        defer { fixture.removeFiles() }
        let originalID = try fixture.history.begin(action: .dictation())
        try fixture.history.update(originalID) { $0.status = .interrupted }
        let retry = fixture.controller(generate: { _, _ in Issue.record("No input"); return "unexpected" })
        await retry.retry(try #require(fixture.history.entry(id: originalID)))?.value
        #expect(try fixture.diskEntry().status == .failed)
        #expect(try fixture.diskEntry().errorMessage?.contains("no recoverable recording") == true)
        #expect(fixture.deliveries.isEmpty)
    }
}

@MainActor
private final class RetryHistoryFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("retry-history-\(UUID())")
    lazy var history = HistoryStore(directory: directory)
    let state = AppState()
    var deliveries: [String] = []
    func controller(transcribe: @escaping (VoiceAudio) async throws -> String = { _ in
        Issue.record("Existing transcript must skip speech recognition"); return "unexpected"
    }, generate: @escaping (String, String) async throws -> String) -> HistoryRetryController {
        HistoryRetryController(history: history, state: state,
            loadAudio: { try await HistoryAudioLoader.load($0) }, transcribe: transcribe, generate: generate,
            deliver: { [self] result in
                #expect((try? diskEntry().result) == result)
                #expect((try? diskEntry().stage) == .delivery)
                deliveries.append(result)
                return .historyOnly
            }, feedback: { _ in })
    }
    func diskEntry() throws -> HistoryEntry {
        let id = try #require(history.entries.first?.id)
        return try JSONDecoder().decode(HistoryEntry.self, from: Data(contentsOf:
            directory.appendingPathComponent(id.uuidString).appendingPathComponent("entry.json")))
    }
    func removeFiles() { try? FileManager.default.removeItem(at: directory) }
}
