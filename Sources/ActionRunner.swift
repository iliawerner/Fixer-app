import Foundation
import AppKit

/// Owns a complete text run. Inputs and outputs become recoverable before any
/// provider request or paste. All system boundaries are injectable for tests.
@MainActor
final class ActionRunner {
    static let shared = ActionRunner()

    enum Feedback {
        case working(String)
        case busy(String)
        case finished(HistoryDelivery)
        case error(String)
    }

    private let history: HistoryStore
    private let state: AppState
    private let captureTarget: () -> VoiceInsertionTarget?
    private let readSelection: (VoiceInsertionTarget) -> String?
    private let hasAccessibility: () -> Bool
    private let generate: (String, String) async throws -> String
    private let deliver: (String, VoiceInsertionTarget?) async -> HistoryDelivery
    private let feedback: (Feedback) -> Void

    init(
        history: HistoryStore? = nil,
        state: AppState? = nil,
        captureTarget: (() -> VoiceInsertionTarget?)? = nil,
        readSelection: ((VoiceInsertionTarget) -> String?)? = nil,
        hasAccessibility: (() -> Bool)? = nil,
        generate: ((String, String) async throws -> String)? = nil,
        deliver: ((String, VoiceInsertionTarget?) async -> HistoryDelivery)? = nil,
        feedback: ((Feedback) -> Void)? = nil
    ) {
        self.history = history ?? .shared
        self.state = state ?? .shared
        self.captureTarget = captureTarget ?? { SystemVoiceInsertionTarget().capture() }
        self.readSelection = readSelection ?? { SystemVoiceInsertionTarget().selectedText(in: $0) }
        self.hasAccessibility = hasAccessibility ?? { PermissionsManager.isAccessibilityGranted }
        self.generate = generate ?? { try await GeminiAPI.shared.generateContent(model: $0, prompt: $1) }
        self.deliver = deliver ?? { await ResultDeliveryService.shared.deliver($0, to: $1) }
        self.feedback = feedback ?? { event in
            switch event {
            case .working(let name): HUDManager.shared.showWorking(actionName: name)
            case .busy(let name): HUDManager.shared.showBusy(actionName: name)
            case .finished(.pasteSent): HUDManager.shared.showPasteSent()
            case .finished(let delivery): HUDManager.shared.showHistorySaved(copied: delivery == .copied)
            case .error(let message): HUDManager.shared.showError(message)
            }
        }
    }

    @discardableResult
    func run(action: MacroAction) -> Task<Void, Never>? {
        guard action.isEnabled else { return nil }
        guard !state.isProcessing else {
            feedback(.busy(state.processingActionName ?? action.name))
            return nil
        }
        state.isProcessing = true
        state.processingActionName = action.name
        state.lastError = nil
        let target = captureTarget()
        let granted = hasAccessibility()
        state.accessibilityGranted = granted
        // Capture the source before yielding or showing UI: even a failed
        // first disk write should leave the verified original recoverable in memory.
        let source = granted ? target.flatMap(readSelection) : nil
        feedback(.working(action.name))

        return Task { @MainActor in
            defer {
                self.state.isProcessing = false
                self.state.processingActionName = nil
            }
            var historyID: UUID?
            do {
                let id = try self.history.begin(action: action, sourceAppName: target?.sourceAppName,
                                                sourceText: source ?? "")
                historyID = id
                guard granted else { throw RunError.accessibilityRequired }

                // AX reads have a source element and range. An unrelated clipboard
                // writer must never become selected text sent to the provider.
                guard let prompt = Self.buildPrompt(template: action.promptTemplate,
                                                    selectionText: source ?? "") else {
                    throw RunError.selectionUnavailable
                }
                // Append must preserve a selected source even when the prompt
                // does not consume {text}; never replace unreadable text blindly.
                if action.outputMode == .append, target?.selectionLength != 0, source == nil {
                    throw RunError.selectionUnavailable
                }
                try self.history.update(id) {
                    $0.prompt = prompt
                    $0.stage = .generation
                }
                let response = try await self.generate(action.modelName, prompt)
                try Task.checkCancellation()
                let result = Self.composeOutput(mode: action.outputMode,
                                                selectionText: source ?? "", response: response)
                try self.history.update(id) {
                    $0.result = result
                    $0.stage = .delivery
                }
                let outcome = await self.deliver(result, target)
                try self.history.update(id) {
                    $0.status = .succeeded
                    $0.delivery = outcome
                }
                self.feedback(.finished(outcome))
            } catch {
                let message = error.localizedDescription
                if let id = historyID {
                    try? self.history.update(id) {
                        if case GeminiAPI.APIError.incompleteResponse(let partial) = error {
                            $0.result = partial
                        }
                        $0.status = error is CancellationError ? .cancelled : .failed
                        $0.errorMessage = message
                    }
                }
                self.state.lastError = message
                self.feedback(.error(message))
            }
        }
    }

    enum RunError: LocalizedError {
        case accessibilityRequired
        case selectionUnavailable

        var errorDescription: String? {
            switch self {
            case .accessibilityRequired:
                return "Enable Accessibility for Fixer in System Settings → Privacy & Security."
            case .selectionUnavailable:
                return "Could not verify the selected text. Select text in an accessible field and try again. No text was sent."
            }
        }
    }

    // MARK: - Pure helpers (no I/O — unit tested directly)

    /// Builds the prompt sent to the model. Returns nil when the template requires
    /// `{text}` but the selection is empty — the signal for the caller to abort.
    /// A template without `{text}` gets the selection appended (or is sent alone).
    nonisolated static func buildPrompt(template: String, selectionText: String) -> String? {
        if template.contains("{text}") {
            guard !selectionText.isEmpty else { return nil }
            return template.replacingOccurrences(of: "{text}", with: selectionText)
        }
        if !selectionText.isEmpty {
            return template + "\n\n" + selectionText
        }
        return template
    }

    /// Composes what gets pasted back: in `.append` mode the response is appended
    /// below the original selection, otherwise it replaces the selection.
    nonisolated static func composeOutput(mode: ActionOutputMode, selectionText: String, response: String) -> String {
        if mode == .append && !selectionText.isEmpty {
            return selectionText + "\n" + response
        }
        return response
    }
}
