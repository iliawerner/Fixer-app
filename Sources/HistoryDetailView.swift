import SwiftUI

struct HistoryDetailView: View {
    let entry: HistoryEntry
    let audioURL: URL?
    let isProcessing: Bool
    let onRetry: (HistoryEntry) -> Void
    let onCopy: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.action.name)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                    Label(HistoryEntryPresentation.status(entry), systemImage: HistoryEntryPresentation.symbol(entry))
                        .foregroundStyle(entry.status == .failed ? Fixer.safeText : Fixer.textDim)
                    Text(entry.createdAt, format: .dateTime.year().month(.wide).day().hour().minute().second())
                        .foregroundStyle(Fixer.muted)
                    if let sourceApp = entry.sourceAppName {
                        LabeledContent("From", value: sourceApp)
                    }
                    if entry.action.usesVoiceInput {
                        LabeledContent(
                            "Transcription model",
                            value: entry.transcriptionModelName?.replacingOccurrences(of: "models/", with: "") ?? "Not recorded"
                        )
                    }
                    if entry.action.kind != .dictation {
                        LabeledContent("Action model", value: entry.action.modelName.replacingOccurrences(of: "models/", with: ""))
                    }
                    HStack(spacing: 12) {
                        Button(HistoryEntryPresentation.retryLabel(entry), systemImage: "arrow.clockwise") {
                            onRetry(entry)
                        }
                        .buttonStyle(FixerPrimaryButton())
                        .disabled(isProcessing || !HistoryEntryPresentation.canRetry(entry, hasAudio: audioURL != nil))
                        .help(isProcessing ? "Wait for the current action to finish" : "Creates a new run using the saved input. The result is saved to History.")
                        Spacer()
                        Button("Delete run", systemImage: "trash", action: onDelete)
                            .labelStyle(.iconOnly)
                            .disabled(entry.isActive)
                            .help(entry.isActive ? "A running action cannot be deleted" : "Delete this run and its recording")
                    }
                    if isProcessing {
                        Text("Another action is running. You can still read, copy and export saved runs.")
                            .font(.callout)
                            .foregroundStyle(Fixer.muted)
                    }
                }
                .padding(.bottom, 4)

                if let message = entry.errorMessage {
                    Label {
                        Text(message).textSelection(.enabled)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.callout)
                    .foregroundStyle(Fixer.safeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Fixer.warningWash)
                }
                if entry.isActive && entry.stage == .capture && entry.action.usesVoiceInput {
                    Label("Recording is being saved. Playback and export become available when recording stops.", systemImage: "waveform")
                        .font(.callout)
                        .foregroundStyle(Fixer.muted)
                } else if let audioURL {
                    HistoryAudioSection(url: audioURL, duration: entry.audioDuration)
                        .id(entry.id)
                } else if entry.audioFileName != nil {
                    Text("The recording file is unavailable. Any saved text remains below.")
                        .foregroundStyle(Fixer.safeText)
                }
                if !entry.sourceText.isEmpty {
                    HistoryTextSection(title: "Original", text: entry.sourceText, onCopy: onCopy)
                }
                if let transcript = entry.transcript, !transcript.isEmpty {
                    HistoryTextSection(title: "Transcript", text: transcript, onCopy: onCopy)
                }
                if let result = entry.result, !result.isEmpty {
                    HistoryTextSection(title: entry.status == .failed ? "Result — may be incomplete" : "Result", text: result, onCopy: onCopy)
                }
                if let prompt = entry.prompt, !prompt.isEmpty {
                    DisclosureGroup("Used prompt") {
                        HistoryTextSection(title: "Prompt", text: prompt, onCopy: onCopy)
                            .padding(.top, 8)
                    }
                    .font(.callout)
                }
            }
            .padding(22)
        }
        .background(Fixer.base)
        .foregroundStyle(Fixer.text)
    }
}
