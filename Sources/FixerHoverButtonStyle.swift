import SwiftUI

/// Shared hover, keyboard-focus, and press feedback for Fixer's quiet controls.
/// Geometry never changes on hover, so neighboring titlebar and form content
/// remains stationary while the control becomes unmistakably interactive.
struct FixerHoverButtonStyle: ButtonStyle {
    enum Variant: Equatable {
        case toolbar
        case quiet
        case inline
        case row
    }

    let variant: Variant

    init(_ variant: Variant = .quiet) {
        self.variant = variant
    }

    func makeBody(configuration: Configuration) -> some View {
        Surface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            variant: variant
        )
    }

    private struct Surface<Label: View>: View {
        let label: Label
        let isPressed: Bool
        let variant: Variant

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false

        var body: some View {
            label
                .foregroundStyle(foreground)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minWidth: minimumWidth, minHeight: minimumHeight)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(background)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(border, lineWidth: isFocused ? 1.5 : 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .scaleEffect(reduceMotion ? 1 : (isPressed ? pressedScale : 1))
                .offset(y: reduceMotion ? 0 : (isPressed ? 1 : 0))
                .opacity(isEnabled ? 1 : 0.46)
                .onHover { isHovered = $0 }
                .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isHovered)
                .animation(FixerMotion.press(reduceMotion: reduceMotion), value: isPressed)
        }

        private var foreground: Color {
            isHovered || isPressed || isFocused ? Fixer.text : Fixer.textDim
        }

        private var background: Color {
            if variant == .row { return .clear }
            if variant == .toolbar {
                if isPressed { return Fixer.text.opacity(0.14) }
                if isHovered || isFocused { return Fixer.text.opacity(0.08) }
                return .clear
            }
            if isPressed { return Fixer.yellowWash.opacity(0.92) }
            if isHovered || isFocused {
                return Fixer.film.opacity(0.90)
            }
            return .clear
        }

        private var border: Color {
            if isFocused { return Fixer.text.opacity(0.70) }
            if variant == .toolbar {
                return isPressed || isHovered ? Fixer.text.opacity(0.22) : .clear
            }
            if isPressed || isHovered { return Fixer.yellowDark.opacity(0.68) }
            return .clear
        }

        private var horizontalPadding: CGFloat {
            switch variant {
            case .toolbar: 0
            case .quiet: 7
            case .inline: 4
            case .row: 0
            }
        }

        private var verticalPadding: CGFloat {
            switch variant {
            case .toolbar: 0
            case .quiet: 5
            case .inline: 3
            case .row: 0
            }
        }

        private var minimumWidth: CGFloat? {
            variant == .toolbar ? WorkspaceChromeMetrics.titlebarControlSize : nil
        }

        private var minimumHeight: CGFloat? {
            variant == .toolbar ? WorkspaceChromeMetrics.titlebarControlSize : nil
        }

        private var cornerRadius: CGFloat {
            variant == .inline ? 5 : 7
        }

        private var pressedScale: CGFloat {
            variant == .row ? 0.992 : 0.97
        }
    }
}
