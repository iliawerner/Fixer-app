import AVFoundation
import Foundation
import Testing
@testable import fixer

@Suite(.serialized)
@MainActor
struct VoiceHistoryLifecycleTests {
    @Test func initialPersistenceFailureKeepsVerifiedSourceInMemory() async throws {
        let fixture = try VoiceHistoryFixture()
        defer { fixture.removeFiles() }
        // A regular file where a directory is required deterministically fails
        // the first save without relying on disk permissions or filling a disk.
        try Data("blocked directory".utf8).write(to: fixture.directory)
        let runner = fixture.runner(transcriber: ClosureHistoryTranscriber { _ in
            Issue.record("Failed first history write must stop before upload")
            return "unexpected"
        })
        runner.toggle(action: .dictation())
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.sourceText == "Original")
        #expect(entry.status == .failed)
        #expect(fixture.history.persistenceError != nil)
        #expect(!fixture.state.isProcessing)
        #expect(fixture.target.readCount == 1)
    }

    @Test func audioIsDurableBeforeTranscriptionAndSurvivesProviderFailure() async throws {
        let fixture = try VoiceHistoryFixture()
        defer { fixture.removeFiles() }
        let transcriber = ClosureHistoryTranscriber { audio in
            await MainActor.run {
                let entry = fixture.history.entries.first!
                #expect(entry.stage == .transcription)
                #expect(entry.transcriptionModelName == VoiceTranscriptionPolicy.modelID)
                #expect(entry.audioFileName?.hasSuffix(".wav") == true)
                #expect(fixture.history.audioURL(for: entry) != nil)
                #expect(audio.duration == 0.1)
            }
            throw VoiceCaptureError.couldNotStart("Provider unavailable")
        }
        let runner = fixture.runner(transcriber: transcriber)
        runner.toggle(action: .dictation())
        try await fixture.waitUntil { runner.isListening }
        runner.toggle(action: .dictation())
        try await fixture.waitUntil { !fixture.state.isProcessing }
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.status == .failed)
        #expect(entry.sourceText == "Original")
        #expect(entry.errorMessage?.contains("Provider unavailable") == true)
        let url = try #require(fixture.history.audioURL(for: entry))
        let audio = try await HistoryAudioLoader.load(url)
        #expect(audio.duration == 0.1)
        #expect(fixture.deliveries.isEmpty)
        let reloaded = HistoryStore(directory: fixture.directory)
        #expect(reloaded.entries.first?.status == .failed)
        #expect(reloaded.audioURL(for: try #require(reloaded.entries.first)) != nil)
    }

    @Test func transcriptAndPromptAreSavedBeforeGenerationAndResultBeforeDelivery() async throws {
        let fixture = try VoiceHistoryFixture()
        defer { fixture.removeFiles() }
        let action = MacroAction(name: "Voice edit", shortcutName: .init("historyVoiceEdit"),
                                 promptTemplate: "Rewrite {text}: {voice}", outputMode: .append)
        let runner = fixture.runner(
            transcriber: ClosureHistoryTranscriber { _ in "make warmer" },
            generator: { _, prompt in
                let disk = HistoryStore(directory: fixture.directory)
                let entry = try #require(disk.entries.first)
                #expect(entry.sourceText == "Original")
                #expect(entry.transcript == "make warmer")
                #expect(entry.prompt == "Rewrite Original: make warmer")
                #expect(entry.stage == .generation)
                #expect(prompt == entry.prompt)
                return "Updated"
            }
        )
        runner.toggle(action: action)
        try await fixture.waitUntil { runner.isListening }
        runner.toggle(action: action)
        try await fixture.waitUntil { !fixture.state.isProcessing }
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.status == .succeeded)
        #expect(entry.delivery == .historyOnly)
        #expect(fixture.deliveries == ["Original\nUpdated"])
        #expect(entry.result == fixture.deliveries.first)
        #expect(fixture.target.readCount == 1)
    }

    @Test func cancellationKeepsSourceRecordingWithoutCallingProvider() async throws {
        let fixture = try VoiceHistoryFixture()
        defer { fixture.removeFiles() }
        let runner = fixture.runner(transcriber: ClosureHistoryTranscriber { _ in
            Issue.record("Cancellation must never upload audio")
            return "unexpected"
        })
        runner.toggle(action: .dictation())
        try await fixture.waitUntil { runner.isListening }
        runner.cancelBeforeUpload()
        try await fixture.waitUntil { !fixture.state.isProcessing }
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.status == .cancelled)
        #expect(entry.stage == .capture)
        #expect(entry.audioFileName?.hasSuffix(".caf") == true)
        let url = try #require(fixture.history.audioURL(for: entry))
        let audio = try await HistoryAudioLoader.load(url)
        #expect(audio.duration == 0.1)
        #expect(fixture.deliveries.isEmpty)
    }

    @Test func cancellingEncodingWaitsForLocalWorkAndNeverUploads() async throws {
        let gate = HistoryEncodingGate()
        let fixture = try VoiceHistoryFixture(encoder: { _, _ in try await gate.encode() })
        defer { fixture.removeFiles() }
        let runner = fixture.runner(transcriber: ClosureHistoryTranscriber { _ in
            Issue.record("Cancelled encoding must never upload")
            return "unexpected"
        })
        runner.toggle(action: .dictation())
        try await fixture.waitUntil { runner.isListening }
        runner.toggle(action: .dictation())
        await gate.waitUntilEntered()
        runner.cancelBeforeUpload()
        #expect(fixture.state.isProcessing)
        #expect(fixture.history.entries.first?.status == .running)
        await gate.finish()
        try await fixture.waitUntil { !fixture.state.isProcessing }
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.status == .cancelled)
        #expect(entry.audioFileName?.hasSuffix(".caf") == true)
        #expect(fixture.history.audioURL(for: entry) != nil)
        #expect(fixture.deliveries.isEmpty)
    }

    @Test func encodingFailureKeepsRecoverableAudioAndNeverUploads() async throws {
        let fixture = try VoiceHistoryFixture(encodingFails: true)
        defer { fixture.removeFiles() }
        let runner = fixture.runner(transcriber: ClosureHistoryTranscriber { _ in
            Issue.record("Encoding failure must never upload audio")
            return "unexpected"
        })
        runner.toggle(action: .dictation())
        try await fixture.waitUntil { runner.isListening }
        runner.toggle(action: .dictation())
        try await fixture.waitUntil { !fixture.state.isProcessing }
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.status == .failed)
        #expect(entry.stage == .capture)
        let url = try #require(fixture.history.audioURL(for: entry))
        #expect(url.pathExtension == "caf")
        let audio = try await HistoryAudioLoader.load(url)
        #expect(audio.duration == 0.1)
    }

    @Test func incompleteGenerationKeepsTranscriptAndPartialResultWithoutDelivery() async throws {
        let fixture = try VoiceHistoryFixture()
        defer { fixture.removeFiles() }
        let action = MacroAction(name: "Voice edit", shortcutName: .init("historyPartialVoice"), promptTemplate: "Rewrite {voice}")
        let runner = fixture.runner(transcriber: ClosureHistoryTranscriber { _ in "a complete transcript" },
                                    generator: { _, _ in throw GeminiAPI.APIError.incompleteResponse("partial output") })
        runner.toggle(action: action)
        try await fixture.waitUntil { runner.isListening }
        runner.toggle(action: action)
        try await fixture.waitUntil { !fixture.state.isProcessing }
        let entry = try #require(fixture.history.entries.first)
        #expect(entry.status == .failed)
        #expect(entry.stage == .generation)
        #expect(entry.transcript == "a complete transcript")
        #expect(entry.result == "partial output")
        #expect(fixture.deliveries.isEmpty)
    }
}

@MainActor
private final class VoiceHistoryFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("voice-history-\(UUID().uuidString)")
    let history: HistoryStore
    let state = AppState()
    let target = HistoryInsertionTarget()
    let capture: VoiceAudioCapture
    var deliveries: [String] = []

    init(encodingFails: Bool = false, encoder: VoiceAudioCapture.Encoder? = nil) throws {
        history = HistoryStore(directory: directory)
        capture = VoiceAudioCapture(
            authorizer: HistoryMicrophoneAuthorizer(), maximumDuration: 300,
            sessionFactory: { _ in FakeRecoverableCaptureSession() },
            encoder: encoder ?? { samples, rate in
                if encodingFails { throw VoiceCaptureError.couldNotEncode }
                return try WAVAudioEncoder.encodeMonoPCM16(samples: samples, sourceSampleRate: rate)
            },
            limitSleeper: { _ in try await Task.sleep(for: .seconds(300)) }
        )
    }

    func runner(transcriber: any VoiceTranscribing,
                generator: @escaping @MainActor (String, String) async throws -> String = { _, _ in "Result" }) -> VoiceActionRunner {
        VoiceActionRunner(capture: capture, transcriber: transcriber,
                          insertionTarget: target, keyStore: HistoryKeyStore(),
                          history: history, appState: state, generator: generator,
                          deliver: { [self] result, _ in
                              // Delivery must never run before the result is durable.
                              let disk = HistoryStore(directory: directory)
                              #expect(disk.entries.first?.result == result)
                              #expect(disk.entries.first?.stage == .delivery)
                              deliveries.append(result)
                              return .historyOnly
                          }, accessibilityCheck: { true }, monitorsEscape: false, showsHUD: false)
    }

    func waitUntil(_ predicate: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !predicate() && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(predicate(), "Voice lifecycle did not reach expected state")
    }

    func removeFiles() { try? FileManager.default.removeItem(at: directory) }
}

private struct ClosureHistoryTranscriber: VoiceTranscribing {
    let block: @Sendable (VoiceAudio) async throws -> String
    init(_ block: @escaping @Sendable (VoiceAudio) async throws -> String) { self.block = block }
    func transcribe(_ audio: VoiceAudio) async throws -> String { try await block(audio) }
}

private struct HistoryMicrophoneAuthorizer: MicrophoneAuthorizing {
    func authorizationStatus() -> MicrophoneAuthorizationStatus { .authorized }
    func requestAuthorization() async -> Bool { true }
}

@MainActor
private final class HistoryInsertionTarget: VoiceInsertionTargeting {
    private(set) var readCount = 0
    func capture() -> VoiceInsertionTarget? {
        VoiceInsertionTarget(processIdentifier: 99, sourceAppName: "Test editor",
                             selectedTextRange: CFRange(location: 0, length: 8))
    }
    func isCurrent(_ target: VoiceInsertionTarget) -> Bool { false }
    func selectedText(in target: VoiceInsertionTarget) -> String? {
        readCount += 1
        return readCount == 1 ? "Original" : "Changed after capture"
    }
}

private final class HistoryKeyStore: APIKeyStoring {
    func saveAPIKey(_ key: String) throws {}
    func getAPIKey() throws -> String? { "injected-test-key" }
    func deleteAPIKey() throws {}
}

private final class FakeRecoverableCaptureSession: VoiceAudioCaptureSession {
    let sampleRate: Double = 16_000
    private var writer: RecoverableVoiceRecording?
    private var samples = [Float](repeating: 0.2, count: 1_600)
    func prepareRecovery(at url: URL) throws {
        writer = try RecoverableVoiceRecording(url: url, sampleRate: sampleRate, maximumDuration: 300)
    }
    func start() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(samples.count)))
        buffer.frameLength = UInt32(samples.count)
        let channel = try #require(buffer.floatChannelData?[0])
        for index in samples.indices { channel[index] = samples[index] }
        writer?.append(buffer)
    }
    func stop() {}
    func finishRecovery() throws { try writer?.finish() }
    var recoveryError: Error? { writer?.error }
    func takeSamples() -> [Float] { let result = samples; samples = []; return result }
    func discard() { samples = [] }
    func level() -> Float { 0.2 }
}

private actor HistoryEncodingGate {
    private var continuation: CheckedContinuation<Data, Error>?
    private var entered: CheckedContinuation<Void, Never>?
    func encode() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            entered?.resume()
            entered = nil
        }
    }
    func waitUntilEntered() async {
        if continuation != nil { return }
        await withCheckedContinuation { entered = $0 }
    }
    func finish() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}
