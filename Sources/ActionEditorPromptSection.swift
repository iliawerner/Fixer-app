import SwiftUI

/// The Action's primary work surface. Its bounded height follows the window,
/// while the rest of the editor stays compact and immediately reachable.
struct ActionEditorPromptSection: View {
    @Binding var action: MacroAction
    let editorHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isPromptFocused: Bool
    @State private var isPromptHovered = false
    @State private var hoveredToken: String?

    var body: some View {
        let token = Text("{text}")
            .font(.caption.monospaced())
            .bold()

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ActionEditorSectionLabel("Prompt")

                Spacer()

                HStack(spacing: 6) {
                    tokenButton(
                        token: "{text}",
                        accessibilityLabel: "Insert selected text token",
                        help: "Insert the selected text variable"
                    )
                    tokenButton(
                        token: "{voice}",
                        accessibilityLabel: "Insert dictation token",
                        help: "Ask for dictation when this Action runs"
                    )
                }
            }

            TextEditor(text: $action.promptTemplate)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(Fixer.text)
                .focused($isPromptFocused)
                .frame(height: max(ActionEditorMetrics.promptMinimumHeight, editorHeight))
                .padding(11)
                .background(Fixer.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isPromptFocused
                                ? Fixer.yellowDark
                                : (isPromptHovered ? Fixer.line2 : Fixer.line),
                            lineWidth: isPromptFocused ? 2 : 1
                        )
                }
                .clipShape(.rect(cornerRadius: 8))
                .onHover { isPromptHovered = $0 }
                .animation(FixerMotion.focus(reduceMotion: reduceMotion), value: isPromptFocused)
                .animation(FixerMotion.focus(reduceMotion: reduceMotion), value: isPromptHovered)
                .accessibilityLabel("Prompt")

            Text("Use \(token) for the selection and {voice} for dictation. Voice Actions listen before sending the prompt.")
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func tokenButton(
        token: String,
        accessibilityLabel: String,
        help: String
    ) -> some View {
        let isHovered = hoveredToken == token
        Button {
            action.promptTemplate += token
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.caption.bold())
                Text(token)
                    .font(.caption.monospaced())
                    .bold()
            }
            .foregroundStyle(Fixer.textDim)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isHovered ? Fixer.yellowWash : Fixer.film)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHovered ? Fixer.yellowDark.opacity(0.65) : Fixer.line,
                        lineWidth: 1
                    )
            }
            .clipShape(.rect(cornerRadius: 6))
            .scaleEffect(isHovered && !reduceMotion ? 1.025 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hoveredToken = $0 ? token : nil }
        .animation(FixerMotion.control(reduceMotion: reduceMotion), value: isHovered)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}
