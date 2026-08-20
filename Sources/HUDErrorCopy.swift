import Foundation

/// Converts a technical run failure into the two pieces the compact HUD can
/// explain well: what happened, followed by one useful next step.
struct HUDErrorCopy: Equatable {
    let title: String
    let detail: String

    init(message rawMessage: String) {
        let message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if message.localizedStandardContains("No text selected") {
            title = "No text selected"
            detail = "Select text, then run the shortcut again."
            return
        }

        if message.localizedStandardContains("selection through Accessibility") {
            title = "Couldn’t read this selection"
            detail = "Use Replace without {text}, or try another field."
            return
        }

        if message.localizedStandardContains("read the selection") {
            title = "Couldn’t read the selection"
            detail = "Select the text again, then run the shortcut."
            return
        }

        if message.localizedStandardContains("Accessibility") {
            title = "Accessibility permission needed"
            detail = "Enable it in System Settings → Privacy & Security."
            return
        }

        if message.localizedStandardContains("No Gemini API key") {
            title = "API key needed"
            detail = "Open Setup, add the Gemini API key, then try again."
            return
        }

        if message.localizedStandardContains("API key") {
            title = "Check the API key"
            detail = "Open Setup, update the Gemini API key, then try again."
            return
        }

        if message.localizedStandardContains("Invalid model") {
            title = "Model isn’t available"
            detail = "Choose another model for this action, then try again."
            return
        }

        if let sentenceBreak = Self.firstSentenceBreak(in: message) {
            title = Self.trimSentenceEnding(String(message[...sentenceBreak]))
            let nextIndex = message.index(after: sentenceBreak)
            detail = String(message[nextIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }

        title = message.isEmpty ? "Couldn’t finish" : Self.trimSentenceEnding(message)
        detail = "Open the menu for details, then try again."
    }

    private static func firstSentenceBreak(in message: String) -> String.Index? {
        message.indices.first { index in
            ".!?".contains(message[index])
                && message.index(after: index) < message.endIndex
                && message[message.index(after: index)].isWhitespace
        }
    }

    private static func trimSentenceEnding(_ value: String) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?"))
        )
    }
}
