import SwiftUI

/// The Action's primary work surface. Its bounded height follows the window,
/// while the rest of the editor stays compact and immediately reachable.
struct ActionEditorPromptSection: View {
    @Binding var action: MacroAction
    let editorHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isPromptFocused: Bool
    @State private var isPromptHovered = false
    @State private var isTokenHovered = false

    var body: some View {
        let token = Text("{text}")
            .font(.caption.monospaced())
            .bold()

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ActionEditorSectionLabel("Prompt")

                Spacer()

                Button(action: insertSelectionToken) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                        Text("{text}")
                            .font(.caption.monospaced())
                            .bold()
                    }
                    .foregroundStyle(Fixer.textDim)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(isTokenHovered ? Fixer.yellowWash : Fixer.film)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isTokenHovered ? Fixer.yellowDark.opacity(0.65) : Fixer.line,
                                lineWidth: 1
                            )
                    }
                    .clipShape(.rect(cornerRadius: 6))
                    .scaleEffect(isTokenHovered && !reduceMotion ? 1.025 : 1)
                }
                .buttonStyle(.plain)
                .onHover { isTokenHovered = $0 }
                .animation(FixerMotion.control(reduceMotion: reduceMotion), value: isTokenHovered)
                .accessibilityLabel("Insert selected text token")
                .help("Insert {text} at the end of the prompt")
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

            Text("Use \(token) to position the selected text. Otherwise it is added at the end.")
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func insertSelectionToken() {
        action.promptTemplate += "{text}"
    }
}
