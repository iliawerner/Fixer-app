import Foundation

/// Human-readable state shared by the history list and detail view.
enum HistoryEntryPresentation {
    static func status(_ entry: HistoryEntry) -> String {
        switch entry.status {
        case .running:
            switch entry.stage {
            case .capture: entry.action.usesVoiceInput ? "Recording" : "Capturing text"
            case .transcription: "Transcribing"
            case .generation: "Processing"
            case .delivery: "Delivering"
            }
        case .succeeded:
            switch entry.delivery {
            case .pasteSent: "Paste sent"
            case .copied: "Copied to clipboard"
            case .historyOnly, nil: "Saved to History"
            }
        case .failed: "Failed"
        case .interrupted: "Interrupted"
        case .cancelled: "Cancelled"
        }
    }

    static func symbol(_ entry: HistoryEntry) -> String {
        switch entry.status {
        case .running: "ellipsis.circle"
        case .succeeded: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        case .interrupted: "pause.circle"
        case .cancelled: "xmark.circle"
        }
    }

    static func preview(_ entry: HistoryEntry) -> String {
        for candidate in [entry.result, entry.transcript, entry.sourceText, entry.errorMessage] {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return entry.audioFileName == nil ? "No text captured" : "Audio recording"
    }

    static func canRetry(_ entry: HistoryEntry, hasAudio: Bool) -> Bool {
        guard !entry.isActive else { return false }
        if entry.action.usesVoiceInput {
            return hasAudio || !(entry.transcript ?? "").isEmpty
        }
        return entry.prompt != nil || !entry.sourceText.isEmpty
            || !entry.action.promptTemplate.contains("{text}")
    }

    static func retryLabel(_ entry: HistoryEntry) -> String {
        if entry.action.usesVoiceInput && (entry.transcript ?? "").isEmpty {
            return "Transcribe again"
        }
        return "Process again"
    }
}
