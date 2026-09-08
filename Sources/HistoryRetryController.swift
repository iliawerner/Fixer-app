import Foundation
import Combine

/// Retries a saved operation using its immutable Action and available source.
/// A retry creates its own record and never revives an old insertion target.
@MainActor
final class HistoryRetryController: ObservableObject {
    static let shared = HistoryRetryController()
    @Published private(set) var isRetrying = false

    private let history: HistoryStore
    private let state: AppState
    private let loadAudio: (URL) async throws -> VoiceAudio
    private let transcribe: (VoiceAudio) async throws -> String
    private let generate: (String, String) async throws -> String
    private let deliver: (String) async -> HistoryDelivery
    private let feedback: (ActionRunner.Feedback) -> Void

    init(
        history: HistoryStore? = nil,
        state: AppState? = nil,
        loadAudio: ((URL) async throws -> VoiceAudio)? = nil,
        transcribe: ((VoiceAudio) async throws -> String)? = nil,
        generate: ((String, String) async throws -> String)? = nil,
        deliver: ((String) async -> HistoryDelivery)? = nil,
        feedback: ((ActionRunner.Feedback) -> Void)? = nil
    ) {
        self.history = history ?? .shared
        self.state = state ?? .shared
        self.loadAudio = loadAudio ?? { try await HistoryAudioLoader.load($0) }
        self.transcribe = transcribe ?? { try await GeminiVoiceTranscriber().transcribe($0) }
        self.generate = generate ?? { try await GeminiAPI.shared.generateContent(model: $0, prompt: $1) }
        self.deliver = deliver ?? { await ResultDeliveryService.shared.deliver($0, to: nil) }
        self.feedback = feedback ?? { event in
            switch event {
            case .working(let name): HUDManager.shared.showWorking(actionName: name)
            case .busy(let name): HUDManager.shared.showBusy(actionName: name)
            case .finished(let outcome): HUDManager.shared.showHistorySaved(copied: outcome == .copied)
            case .error(let message): HUDManager.shared.showError(message)
            }
        }
    }

    @discardableResult
    func retry(_ entry: HistoryEntry) -> Task<Void, Never>? {
        guard !entry.isActive else { return nil }
        guard !state.isProcessing else {
            feedback(.busy(state.processingActionName ?? entry.action.name))
            return nil
        }
        state.isProcessing = true
        state.processingActionName = entry.action.name
        state.lastError = nil
        isRetrying = true
        feedback(.working(entry.action.name))
        // Resolve while the original still exists. An explicit deletion during
        // loading may fail this attempt, but must never resurrect deleted data.
        let audioURL = history.audioURL(for: entry)

        return Task { @MainActor in
            defer {
                self.state.isProcessing = false
                self.state.processingActionName = nil
                self.isRetrying = false
            }
            var historyID: UUID?
            do {
                let id = try self.history.begin(action: entry.action,
                                                sourceAppName: entry.sourceAppName,
                                                sourceText: entry.sourceText)
                historyID = id
                try self.history.update(id) {
                    $0.transcript = entry.transcript
                    $0.transcriptionModelName = entry.transcriptionModelName
                    $0.prompt = entry.prompt
                }
                let result: String
                if entry.action.usesVoiceInput {
                    let transcript: String
                    if let existing = entry.transcript, !existing.isEmpty {
                        transcript = existing
                    } else {
                        guard let audioURL else { throw RetryError.noRecording }
                        let audio = try await self.loadAudio(audioURL)
                        try self.history.saveAudio(audio, for: id)
                        try self.history.update(id) {
                            $0.stage = .transcription
                            $0.transcriptionModelName = VoiceTranscriptionPolicy.modelID
                        }
                        transcript = try await self.transcribe(audio)
                        try Task.checkCancellation()
                        try self.history.update(id) { $0.transcript = transcript }
                    }
                    if entry.action.kind == .dictation {
                        result = transcript
                    } else {
                        guard let prompt = VoiceActionRunner.buildVoicePrompt(
                            template: entry.action.promptTemplate,
                            selectionText: entry.sourceText, transcript: transcript
                        ) else { throw ActionRunner.RunError.selectionUnavailable }
                        result = try await self.generateResult(prompt, entry: entry, id: id)
                    }
                } else {
                    guard let prompt = entry.prompt ?? ActionRunner.buildPrompt(
                        template: entry.action.promptTemplate, selectionText: entry.sourceText
                    ) else { throw ActionRunner.RunError.selectionUnavailable }
                    result = try await self.generateResult(prompt, entry: entry, id: id)
                }
                try Task.checkCancellation()
                try self.history.update(id) {
                    $0.result = result
                    $0.stage = .delivery
                }
                let outcome = await self.deliver(result)
                try self.history.update(id) {
                    $0.status = .succeeded
                    $0.delivery = outcome
                }
                self.feedback(.finished(outcome))
            } catch {
                if let id = historyID {
                    try? self.history.update(id) {
                        $0.status = error is CancellationError ? .cancelled : .failed
                        $0.errorMessage = error.localizedDescription
                        if case GeminiAPI.APIError.incompleteResponse(let partial) = error {
                            $0.result = partial
                        }
                    }
                }
                self.state.lastError = error.localizedDescription
                self.feedback(.error(error.localizedDescription))
            }
        }
    }

    private func generateResult(_ prompt: String, entry: HistoryEntry, id: UUID) async throws -> String {
        try history.update(id) {
            $0.prompt = prompt
            $0.stage = .generation
        }
        let response = try await generate(entry.action.modelName, prompt)
        return ActionRunner.composeOutput(mode: entry.action.outputMode,
                                         selectionText: entry.sourceText, response: response)
    }

    enum RetryError: LocalizedError {
        case noRecording
        var errorDescription: String? {
            "This entry has no recoverable recording. Record the audio again."
        }
    }
}
