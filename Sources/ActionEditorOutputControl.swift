import SwiftUI

/// A branded two-option control that keeps the clarity of a segmented picker
/// without importing the system's blue selection treatment into Fixer's warm
/// palette. Each segment remains an actual Button, so Return/Space activation,
/// focus navigation and VoiceOver semantics continue to work on macOS.
struct ActionEditorOutputControl: View {
    @Binding var mode: ActionOutputMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedMode: ActionOutputMode?
    @State private var hoveredMode: ActionOutputMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActionEditorSectionLabel("Output mode")

            HStack(spacing: 3) {
                ForEach(ActionOutputMode.allCases) { option in
                    Button(action: { select(option) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(Fixer.yellowDark)
                                .opacity(mode == option ? 1 : 0)
                                .accessibilityHidden(true)

                            Text(option.rawValue)
                                .font(.callout)
                                .bold(mode == option)
                        }
                        .foregroundStyle(Fixer.text)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(segmentBackground(for: option))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(
                                    segmentBorder(for: option),
                                    lineWidth: focusedMode == option ? 1.5 : 1
                                )
                        }
                        .clipShape(.rect(cornerRadius: 5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focused($focusedMode, equals: option)
                    .onHover { hoveredMode = $0 ? option : nil }
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                    .accessibilityHint("Changes how Fixer inserts generated text")
                }
            }
            .padding(3)
            .frame(maxWidth: 300, alignment: .leading)
            .background(Fixer.film)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Fixer.line2, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 8))
            .animation(FixerMotion.control(reduceMotion: reduceMotion), value: mode)
            .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: hoveredMode)
            .onMoveCommand(perform: moveSelection)

            Text(helpText)
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var helpText: String {
        switch mode {
        case .replace:
            "Replaces the selection. Undo availability depends on the active app."
        case .append:
            "Keeps the selection and inserts the result on a new line."
        }
    }

    private func segmentBorder(for option: ActionOutputMode) -> Color {
        if focusedMode == option {
            Fixer.text
        } else if mode == option {
            Fixer.selectedControlBorder
        } else if hoveredMode == option {
            Fixer.line2
        } else {
            .clear
        }
    }

    private func segmentBackground(for option: ActionOutputMode) -> Color {
        if mode == option { return Fixer.yellowWash }
        if hoveredMode == option { return Fixer.panel.opacity(0.92) }
        return .clear
    }

    private func select(_ option: ActionOutputMode) {
        focusedMode = option
        guard mode != option else { return }
        mode = option
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let options = ActionOutputMode.allCases
        guard let currentIndex = options.firstIndex(of: focusedMode ?? mode) else {
            return
        }

        let nextIndex: Int
        switch direction {
        case .left:
            nextIndex = max(options.startIndex, currentIndex - 1)
        case .right:
            nextIndex = min(options.index(before: options.endIndex), currentIndex + 1)
        default:
            return
        }

        select(options[nextIndex])
    }
}
