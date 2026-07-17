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
            let usesText = action.promptTemplate.contains("{text}")

            // If a template needs {text} but we couldn't read a selection, abort
            // cleanly and restore the clipboard rather than sending junk to Gemini.
            if usesText && selection.text.isEmpty {
                await ClipboardManager.shared.restore()
                let message = selection.didCopy
                    ? "No text selected."
                    : "Couldn't read the selection. Select text, then trigger the shortcut."
                AppState.shared.lastError = message
                HUDManager.shared.showError(message)
                return
            }

            var finalPrompt = action.promptTemplate
            if usesText {
                finalPrompt = finalPrompt.replacingOccurrences(of: "{text}", with: selection.text)
            } else if !selection.text.isEmpty {
                finalPrompt += "\n\n" + selection.text
            }

            do {
                let response = try await GeminiAPI.shared.generateContent(model: action.modelName, prompt: finalPrompt)

                let textToPaste: String
                if action.outputMode == .append && !selection.text.isEmpty {
                    textToPaste = selection.text + "\n" + response
                } else {
                    textToPaste = response
                }

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
}
