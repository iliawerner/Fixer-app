import Foundation
import AppKit

@MainActor
final class ActionRunner {
    static let shared = ActionRunner()

    private init() {}

    func run(action: MacroAction) {
        guard action.isEnabled else { return }

        // Atomic check-and-set on the main actor: no `await` between the guard and
        // the assignment, so overlapping triggers can't both pass the guard.
        guard !AppState.shared.isProcessing else { return }

        // Accessibility is required to copy the selection and paste the result.
        // Without it the whole flow is a silent no-op, so fail loudly instead.
        AppState.shared.refreshAccessibility()
        guard AppState.shared.accessibilityGranted else {
            AppState.shared.lastError = "Accessibility permission is required."
            HUDManager.shared.showError("Enable Accessibility for fixer in System Settings → Privacy & Security.")
            PermissionsManager.promptForAccessibility()
            return
        }

        AppState.shared.isProcessing = true
        AppState.shared.lastError = nil
        HUDManager.shared.showWorking()

        Task { @MainActor in
            defer {
                AppState.shared.isProcessing = false
            }

            let selection = await ClipboardManager.shared.copySelection()

            // If a template needs {text} but we couldn't read a selection, abort
            // cleanly and restore the clipboard rather than sending junk to Gemini.
            guard let finalPrompt = Self.buildPrompt(template: action.promptTemplate,
                                                     selectionText: selection.text) else {
                await ClipboardManager.shared.restore()
                let message = selection.didCopy
                    ? "No text selected."
                    : "Couldn't read the selection. Select text, then trigger the shortcut."
                AppState.shared.lastError = message
                HUDManager.shared.showError(message)
                return
            }

            do {
                let response = try await GeminiAPI.shared.generateContent(model: action.modelName, prompt: finalPrompt)
                let textToPaste = Self.composeOutput(mode: action.outputMode,
                                                     selectionText: selection.text,
                                                     response: response)
                await ClipboardManager.shared.paste(textToPaste)
                HUDManager.shared.showSuccess()
            } catch {
                // Always restore the clipboard on failure so the user's original
                // contents are never left holding the copied selection.
                await ClipboardManager.shared.restore()
                let message = error.localizedDescription
                AppState.shared.lastError = message
                HUDManager.shared.showError(message)
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
