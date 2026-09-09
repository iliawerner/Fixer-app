import SwiftUI

/// Hover-responsive label for the native Action options Menu.
/// The Menu itself remains native so keyboard and VoiceOver behavior are not
/// replaced by a custom popover merely to achieve branded feedback.
struct ActionOptionsMenuLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    var body: some View {
        Label("Action options", systemImage: "ellipsis")
            .labelStyle(.iconOnly)
            .font(.body.bold())
            .foregroundStyle(Fixer.mastheadText)
            .frame(
                width: WorkspaceChromeMetrics.titlebarControlSize,
                height: WorkspaceChromeMetrics.titlebarControlSize
            )
            .background(Fixer.text.opacity(isHovered || isFocused ? 0.12 : 0))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        Fixer.text.opacity(isHovered || isFocused ? 0.30 : 0),
                        lineWidth: isHovered || isFocused ? 1.5 : 1
                    )
            }
            .clipShape(.rect(cornerRadius: 7))
            .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.025 : 1))
            .contentShape(.rect(cornerRadius: 7))
            .onHover { isHovered = $0 }
            .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isHovered)
            .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isFocused)
    }
}
