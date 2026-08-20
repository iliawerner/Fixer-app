import SwiftUI

/// Plain-language engine and privacy disclosure for Gemini-first dictation.
/// There is deliberately no disabled provider picker: local transcription is a
/// future engine, not a non-working control in the current product.
struct DictationPrivacySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ActionEditorSectionLabel("Recognition")

            Label("Gemini transcription", systemImage: "waveform.and.mic")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Fixer.text)

            Label("Language: Auto — including mixed-language speech", systemImage: "character.bubble")
                .font(.caption)
                .foregroundStyle(Fixer.textDim)

            Text("Audio is sent to Google Gemini for transcription. Fixer does not save your recordings.")
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Fixer.film.opacity(0.58))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Fixer.line, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 8))
    }
}
