import SwiftUI

/// The single canonical enabled state for an Action. The custom ToggleStyle
/// keeps native Toggle data flow and accessibility while using Fixer's compact
/// yellow/dark visual language instead of the unrelated blue system tint.
struct ActionEditorEnabledControl: View {
    @Binding var action: MacroAction
    let onEnabledChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActionEditorSectionLabel("Enabled")

            Toggle(isOn: enabledBinding) {
                Text("Run this action from its shortcut")
                    .font(.caption)
                    .foregroundStyle(Fixer.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(FixerToggleStyle())
            .frame(maxWidth: 320, alignment: .leading)
            .accessibilityLabel("Enabled")
            .accessibilityValue(action.isEnabled ? "On" : "Off")
            .accessibilityHint("Allows this action to run from its global shortcut")
        }
    }

    /// Routes the interaction through SettingsManager's canonical setter. The
    /// Toggle changes that setting exactly once and never performs a competing
    /// direct mutation through `$action.isEnabled`.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { action.isEnabled },
            set: onEnabledChange
        )
    }
}

/// A full-row style gives the explanatory label a stable alignment while the
/// 38×22 track remains visually compact. Thumb position communicates state even
/// when the user enables Differentiate Without Color.
private struct FixerToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration)
    }

    private struct Surface: View {
        let configuration: ToggleStyleConfiguration

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false

        var body: some View {
            Button(action: toggle) {
                HStack(alignment: .center, spacing: 12) {
                    configuration.label

                    Spacer(minLength: 16)

                    ZStack {
                        Capsule()
                            .fill(trackColor)
                            .overlay {
                                Capsule()
                                    .fill(Fixer.film)
                                    .padding(1)
                                    .opacity(configuration.isOn ? 0 : 1)
                            }

                        Circle()
                            .fill(configuration.isOn ? Fixer.onAccent : Fixer.line2)
                            .overlay {
                                Circle()
                                    .fill(Fixer.panel)
                                    .padding(1)
                                    .opacity(configuration.isOn ? 0 : 1)
                            }
                            .frame(width: 16, height: 16)
                            .offset(x: configuration.isOn ? 8 : -8)
                    }
                    .frame(width: 38, height: 22)
                    .accessibilityHidden(true)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered || isFocused ? Fixer.film.opacity(0.78) : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isFocused ? Fixer.text.opacity(0.72) : .clear, lineWidth: 1.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.48)
            .onHover { isHovered = $0 }
            .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isHovered)
            .animation(
                FixerMotion.control(reduceMotion: reduceMotion),
                value: configuration.isOn
            )
        }

        private var trackColor: Color {
            if configuration.isOn {
                return Fixer.yellow.opacity(isHovered ? 0.84 : 1)
            }
            return isHovered ? Fixer.line2.opacity(0.78) : Fixer.line2
        }

        private func toggle() {
            configuration.isOn.toggle()
        }
    }
}
