import SwiftUI

/// Chooses whether voice recording is stopped by a second press or by releasing
/// the shortcut. The control follows Fixer's own warm segmented treatment rather
/// than importing the unrelated blue system accent.
struct DictationActivationControl: View {
    @Binding var mode: VoiceActivationMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedMode: VoiceActivationMode?
    @State private var hoveredMode: VoiceActivationMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActionEditorSectionLabel("Shortcut behavior")

            HStack(spacing: 3) {
                ForEach(VoiceActivationMode.allCases) { option in
                    Button {
                        mode = option
                        focusedMode = option
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .opacity(mode == option ? 1 : 0)
                                .accessibilityHidden(true)

                            Text(option.title)
                                .font(.callout)
                                .bold(mode == option)
                        }
                        .foregroundStyle(Fixer.text)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(background(for: option))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(border(for: option), lineWidth: 1)
                        }
                        .clipShape(.rect(cornerRadius: 5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focused($focusedMode, equals: option)
                    .onHover { hoveredMode = $0 ? option : nil }
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
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

            Text(helpText)
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var helpText: String {
        switch mode {
        case .toggle:
            "Press once to listen, then press again to finish. This also applies to Actions using {voice}."
        case .hold:
            "Hold while speaking, then release to finish. This also applies to Actions using {voice}."
        }
    }

    private func background(for option: VoiceActivationMode) -> Color {
        if mode == option { return Fixer.yellowWash }
        if hoveredMode == option { return Fixer.panel.opacity(0.92) }
        return .clear
    }

    private func border(for option: VoiceActivationMode) -> Color {
        if focusedMode == option { return Fixer.text }
        if mode == option { return Fixer.yellowDark }
        if hoveredMode == option { return Fixer.line2 }
        return .clear
    }
}
