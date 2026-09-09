import SwiftUI

/// A large masthead title with a quiet, stationary editing surface.
/// Hover and focus adjust contrast only; the control never grows or sends an
/// animated line through the yellow header.
struct ActionEditorNameField: View {
    @Binding var name: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var nameAtFocus = ""

    var body: some View {
        TextField("Untitled action", text: $name)
            .textFieldStyle(.plain)
            .font(.title.bold())
            .foregroundStyle(Fixer.mastheadText)
            .lineLimit(1)
            .focused($isFocused)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: WorkspaceChromeMetrics.mastheadTitleControlHeight)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Fixer.text.opacity(surfaceOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Fixer.text.opacity(borderOpacity), lineWidth: 1)
            }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
            .onSubmit { finishEditing() }
            .onExitCommand { cancelEditing() }
            .onChange(of: isFocused, perform: updateFocusState)
            .animation(FixerMotion.focus(reduceMotion: reduceMotion), value: isFocused)
            .animation(FixerMotion.focus(reduceMotion: reduceMotion), value: isHovered)
            .accessibilityLabel("Action name")
            .accessibilityHint("Edit the selected action’s name")
    }

    private var surfaceOpacity: Double {
        if isFocused { return 0.10 }
        if isHovered { return 0.05 }
        return 0
    }

    private var borderOpacity: Double {
        if isFocused { return 0.34 }
        if isHovered { return 0.15 }
        return 0
    }

    private func finishEditing() {
        isFocused = false
    }

    private func cancelEditing() {
        name = nameAtFocus
        isFocused = false
    }

    private func updateFocusState(_ focused: Bool) {
        if focused {
            nameAtFocus = name
        }
    }
}
