import Foundation

/// Voice selection capture is Accessibility-only and fail-closed.
///
/// A pasteboard change after synthetic Command-C cannot be attributed reliably
/// to the target app rather than another clipboard writer. Requiring the exact
/// AX field/range avoids uploading unrelated clipboard text to Gemini.
enum VoiceSelectionCapturePolicy {
    /// Append preserves a non-empty original selection even when the prompt
    /// itself does not consume `{text}`. A known collapsed caret needs no copy;
    /// an unavailable range stays fail-closed because it might hide a selection.
    static func requiresSelection(
        for action: MacroAction,
        selectionLength: Int?
    ) -> Bool {
        if action.promptTemplate.contains("{text}") { return true }
        guard action.kind == .text, action.outputMode == .append else { return false }
        return selectionLength != 0
    }
}

/// Coordinates one voice shortcut from target capture through safe delivery.
///
/// Recording, transcription, and optional Action processing share AppState's
/// process-wide latch with text runs. The original cursor is never re-focused:
/// if it changes, the result is copied for an explicit manual paste.
@MainActor
final class VoiceActionRunner {
    static let shared = VoiceActionRunner(
        capture: VoiceAudioCapture(),
        transcriber: GeminiVoiceTranscriber(),
        insertionTarget: SystemVoiceInsertionTarget(),
        keyStore: KeychainManager.shared
    )

    private enum Stage {
        case preparing
        case listening
        case finishing
        case transcribing
        case applying
        /// Capture is stopped; local permission/encoding work is draining before
        /// the run releases its global ownership and confirms cancellation.
        case cancelling
    }

    private struct Session {
        let id: UUID
        let action: MacroAction
        let activationMode: VoiceActivationMode
        let target: VoiceInsertionTarget
        var selectionText = ""
        var stage: Stage = .preparing
        var stopRequested = false
    }

    private enum RunError: LocalizedError {
        case missingAPIKey
        case missingTarget
        case missingSelection
        case selectionUnavailable

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "No Gemini API key set. Open Setup and paste your key."
            case .missingTarget:
                "Fixer couldn't identify the field where dictation should be inserted."
            case .missingSelection:
                "Select text before running this Action."
            case .selectionUnavailable:
                "Fixer couldn't read this field's selection through Accessibility. Use Replace without {text}, or try another field."
            }
        }
    }

    private let capture: VoiceAudioCapture
    private let transcriber: any VoiceTranscribing
    private let insertionTarget: any VoiceInsertionTargeting
    private let keyStore: any APIKeyStoring
    private let escapeMonitor = VoiceEscapeMonitor()

    private var session: Session?
    private var preparationTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?

    init(
        capture: VoiceAudioCapture,
        transcriber: any VoiceTranscribing,
        insertionTarget: any VoiceInsertionTargeting,
        keyStore: any APIKeyStoring
    ) {
        self.capture = capture
        self.transcriber = transcriber
        self.insertionTarget = insertionTarget
        self.keyStore = keyStore
    }

    var activeActionID: UUID? { session?.action.id }
    var activeActivationMode: VoiceActivationMode? { session?.activationMode }
    var isListening: Bool { session?.stage == .listening }

    /// Toggle-mode event: an idle shortcut starts, the same active shortcut
    /// stops, and another voice Action cannot steal the in-flight session.
    func toggle(action: MacroAction) {
        if session?.action.id == action.id {
            requestStop(actionID: action.id)
        } else if let session {
            HUDManager.shared.showBusy(actionName: session.action.name)
        } else {
            start(action: action, activationMode: .toggle)
        }
    }

    /// Hold-mode key-down. A coordinator-owned edge latch prevents key repeat
    /// from calling this more than once for one physical press.
    func beginHold(action: MacroAction) {
        guard session == nil else {
            if session?.action.id != action.id,
               let activeName = session?.action.name {
                HUDManager.shared.showBusy(actionName: activeName)
            }
            return
        }
        start(action: action, activationMode: .hold)
    }

    /// Hold-mode key-up. If permission or selection capture is still pending,
    /// remember the release and finish immediately once listening begins.
    func endHold(actionID: UUID) {
        requestStop(actionID: actionID)
    }

    /// Cancels only before upload begins. Once Transcribing is visible the audio
    /// request may already have left the Mac, so Escape is no longer monitored.
    func cancelBeforeUpload() {
        guard var current = session,
              current.stage == .preparing
                || current.stage == .listening
                || current.stage == .finishing else { return }

        current.stage = .cancelling
        session = current
        let sessionID = current.id
        let pendingPreparation = preparationTask
        let pendingProcessing = processingTask
        pendingPreparation?.cancel()
        pendingProcessing?.cancel()
        capture.cancel()
        escapeMonitor.stop()
        HUDManager.shared.showVoiceCancelling()

        // Keep AppState owned (and Quit disabled) until every local permission or
        // encoding task acknowledges cancellation and releases its audio bytes.
        Task { @MainActor [weak self] in
            await pendingPreparation?.value
            await pendingProcessing?.value
            guard let self,
                  self.currentSession(sessionID)?.stage == .cancelling else { return }
            self.finishState(sessionID: sessionID)
            HUDManager.shared.showVoiceCancelled()
        }
    }

    // MARK: - Start and stop

    private func start(action: MacroAction, activationMode: VoiceActivationMode) {
        guard action.isEnabled, action.usesVoiceInput else { return }
        guard !AppState.shared.isProcessing else {
            HUDManager.shared.showBusy(
                actionName: AppState.shared.processingActionName ?? action.name
            )
            return
        }

        AppState.shared.refreshAccessibility()
        guard AppState.shared.accessibilityGranted else {
            failBeforeSession("Enable Accessibility for Fixer in System Settings → Privacy & Security.")
            PermissionsManager.promptForAccessibility()
            return
        }

        do {
            guard let key = try keyStore.getAPIKey(),
                  !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RunError.missingAPIKey
            }
        } catch {
            failBeforeSession(error.localizedDescription)
            return
        }

        guard let target = insertionTarget.capture() else {
            failBeforeSession(RunError.missingTarget.localizedDescription)
            return
        }

        let sessionID = UUID()
        session = Session(
            id: sessionID,
            action: action,
            activationMode: activationMode,
            target: target
        )
        AppState.shared.isProcessing = true
        AppState.shared.processingActionName = action.name
        AppState.shared.lastError = nil
        HUDManager.shared.showVoicePreparing(actionName: action.name)

        configureCaptureCallbacks(sessionID: sessionID)
        escapeMonitor.start { [weak self] in
            self?.cancelBeforeUpload()
        }

        preparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let current = self.currentSession(sessionID) else { return }
                try Task.checkCancellation()
                if VoiceSelectionCapturePolicy.requiresSelection(
                    for: action,
                    selectionLength: current.target.selectionLength
                ) {
                    if action.promptTemplate.contains("{text}"),
                       current.target.selectionLength == 0 {
                        throw RunError.missingSelection
                    }
                    if let selectedText = self.insertionTarget.selectedText(in: current.target),
                       !selectedText.isEmpty {
                        guard var live = self.currentSession(sessionID) else { return }
                        live.selectionText = selectedText
                        self.session = live
                    } else {
                        // Never fall back to synthetic Copy here. Its first
                        // pasteboard change could belong to another app and is
                        // therefore not safe to upload as selected text.
                        throw RunError.selectionUnavailable
                    }
                }

                try Task.checkCancellation()
                try await self.capture.start()
                try Task.checkCancellation()
                guard var current = self.currentSession(sessionID) else {
                    self.capture.cancel()
                    return
                }
                current.stage = .listening
                self.session = current
                HUDManager.shared.showVoiceListening(
                    actionName: action.name,
                    activationMode: activationMode
                )

                if current.stopRequested {
                    self.requestStop(actionID: action.id)
                }
            } catch is CancellationError {
                // The explicit cancel path already owns cleanup and truthful UI.
            } catch {
                guard self.currentSession(sessionID)?.stage != .cancelling else {
                    return
                }
                self.fail(error, sessionID: sessionID)
            }
        }
    }

    private func requestStop(actionID: UUID) {
        guard var current = session, current.action.id == actionID else { return }

        switch current.stage {
        case .preparing:
            current.stopRequested = true
            session = current
        case .listening:
            current.stage = .finishing
            session = current
            HUDManager.shared.showVoiceFinishing()

            let sessionID = current.id
            processingTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try Task.checkCancellation()
                    let audio = try await self.capture.stop()
                    try Task.checkCancellation()
                    await self.process(audio, sessionID: sessionID)
                } catch is CancellationError {
                    // Explicit cancel owns cleanup.
                } catch {
                    guard self.currentSession(sessionID)?.stage != .cancelling else {
                        return
                    }
                    self.fail(error, sessionID: sessionID)
                }
            }
        case .finishing, .transcribing, .applying, .cancelling:
            break
        }
    }

    private func configureCaptureCallbacks(sessionID: UUID) {
        capture.onLevelChange = { [weak self] level in
            guard let self,
                  self.session?.id == sessionID,
                  self.session?.stage == .listening else { return }
            HUDManager.shared.updateVoiceLevel(level)
        }
        capture.onAutomaticLimitReached = { [weak self] in
            guard let self, var current = self.currentSession(sessionID) else { return }
            current.stage = .finishing
            self.session = current
            HUDManager.shared.showVoiceFinishing()
        }
        capture.onAutomaticStop = { [weak self] result in
            guard let self, self.currentSession(sessionID) != nil else { return }

            switch result {
            case .success(let audio):
                self.processingTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.process(audio, sessionID: sessionID)
                }
            case .failure(let error):
                self.fail(error, sessionID: sessionID)
            }
        }
    }

    // MARK: - Transcription, Action, delivery

    private func process(_ captured: CapturedVoiceAudio, sessionID: UUID) async {
        guard !Task.isCancelled,
              var current = currentSession(sessionID) else { return }
        if case .cancelling = current.stage { return }
        current.stage = .transcribing
        session = current
        // Encoding is still local and cancellable. Remove Escape only at the
        // exact boundary where the provider request may begin.
        escapeMonitor.stop()
        capture.onLevelChange = nil
        capture.onAutomaticLimitReached = nil
        capture.onAutomaticStop = nil
        HUDManager.shared.showVoiceTranscribing()

        do {
            let audio = VoiceAudio(
                data: captured.data,
                mimeType: captured.mimeType,
                duration: captured.duration
            )
            let transcript = try await transcriber.transcribe(audio)
            try Task.checkCancellation()
            guard var live = currentSession(sessionID) else { return }

            let output: String
            if live.action.kind == .dictation {
                output = transcript
            } else {
                live.stage = .applying
                session = live
                HUDManager.shared.showVoiceApplying(actionName: live.action.name)

                guard let prompt = Self.buildVoicePrompt(
                    template: live.action.promptTemplate,
                    selectionText: live.selectionText,
                    transcript: transcript
                ) else {
                    throw RunError.missingSelection
                }
                let response = try await GeminiAPI.shared.generateContent(
                    model: live.action.modelName,
                    prompt: prompt
                )
                output = ActionRunner.composeOutput(
                    mode: live.action.outputMode,
                    selectionText: live.selectionText,
                    response: response
                )
            }

            try Task.checkCancellation()
            guard let delivery = currentSession(sessionID) else { return }
            let targetIsCurrent = insertionTarget.isCurrent(delivery.target)
            if targetIsCurrent {
                await ClipboardManager.shared.paste(output)
            } else {
                await ClipboardManager.shared.copyText(output)
            }

            let action = delivery.action
            finishState(sessionID: sessionID)
            if targetIsCurrent {
                if action.kind == .dictation {
                    HUDManager.shared.showVoiceInserted()
                } else {
                    HUDManager.shared.showSuccess(
                        actionName: action.name,
                        mode: action.outputMode
                    )
                }
            } else {
                HUDManager.shared.showCopiedForChangedTarget()
            }
        } catch is CancellationError {
            // A cancellable stage's explicit cancel path owns cleanup and copy.
        } catch {
            fail(error, sessionID: sessionID)
        }
    }

    private func currentSession(_ id: UUID) -> Session? {
        guard let session, session.id == id else { return nil }
        return session
    }

    private func fail(_ error: Error, sessionID: UUID) {
        guard currentSession(sessionID) != nil else { return }
        capture.cancel()
        finishState(sessionID: sessionID)
        failBeforeSession(error.localizedDescription)
    }

    private func failBeforeSession(_ message: String) {
        AppState.shared.lastError = message
        HUDManager.shared.showError(message)
    }

    private func finishState(sessionID: UUID) {
        guard session?.id == sessionID else { return }
        escapeMonitor.stop()
        capture.onLevelChange = nil
        capture.onAutomaticLimitReached = nil
        capture.onAutomaticStop = nil
        preparationTask?.cancel()
        processingTask?.cancel()
        preparationTask = nil
        processingTask = nil
        session = nil
        AppState.shared.isProcessing = false
        AppState.shared.processingActionName = nil
    }

    // MARK: - Pure prompt substitution

    /// Replaces original template tokens in one pass. Tokens that appear inside
    /// the selection or transcript remain literal instead of being interpreted
    /// as a second substitution site.
    nonisolated static func buildVoicePrompt(
        template: String,
        selectionText: String,
        transcript: String
    ) -> String? {
        guard !transcript.isEmpty else { return nil }
        if template.contains("{text}"), selectionText.isEmpty { return nil }

        var result = ""
        var cursor = template.startIndex
        while cursor < template.endIndex {
            let textRange = template.range(of: "{text}", range: cursor..<template.endIndex)
            let voiceRange = template.range(of: "{voice}", range: cursor..<template.endIndex)
            let nextRange: Range<String.Index>?

            switch (textRange, voiceRange) {
            case let (text?, voice?):
                nextRange = text.lowerBound < voice.lowerBound ? text : voice
            case let (text?, nil):
                nextRange = text
            case let (nil, voice?):
                nextRange = voice
            case (nil, nil):
                nextRange = nil
            }

            guard let range = nextRange else {
                result.append(contentsOf: template[cursor...])
                break
            }
            result.append(contentsOf: template[cursor..<range.lowerBound])
            if template[range] == "{text}" {
                result.append(selectionText)
            } else {
                result.append(transcript)
            }
            cursor = range.upperBound
        }
        return result
    }
}
