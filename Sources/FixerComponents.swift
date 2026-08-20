import SwiftUI

// MARK: - Type

struct MonoLabel: View {
    let text: String
    var size: CGFloat = 9
    var tracking: CGFloat = 1.8
    var color: Color = Fixer.muted
    var weight: Font.Weight = .regular

    init(
        _ text: String,
        size: CGFloat = 9,
        tracking: CGFloat = 1.8,
        color: Color = Fixer.muted,
        weight: Font.Weight = .regular
    ) {
        self.text = text
        self.size = size
        self.tracking = tracking
        self.color = color
        self.weight = weight
    }

    var body: some View {
        Text(text.uppercased())
            .font(Fixer.mono(size, weight))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

// MARK: - Repair identity

/// The small diagonal plaster is the one recurring identity cue in v2. It is
/// drawn in SwiftUI so it remains crisp in the menu, setup strip and HUD.
struct RepairMark: View {
    var crossed = false
    var fill: Color = Fixer.yellow
    var ink: Color = Fixer.text

    var body: some View {
        ZStack {
            strip(rotation: -38)
            if crossed {
                strip(rotation: 38)
            }
        }
        .accessibilityHidden(true)
    }

    private func strip(rotation: Double) -> some View {
        Capsule(style: .continuous)
            .fill(fill)
            .overlay {
                HStack(spacing: 2.5) {
                    Circle().fill(ink.opacity(0.52)).frame(width: 2.2, height: 2.2)
                    Circle().fill(ink.opacity(0.52)).frame(width: 2.2, height: 2.2)
                    Circle().fill(ink.opacity(0.52)).frame(width: 2.2, height: 2.2)
                }
            }
            .overlay(Capsule(style: .continuous).stroke(ink.opacity(0.72), lineWidth: 1))
            .frame(width: 27, height: 10)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Compact data marks

struct Keycap: View {
    let text: String
    var inverse = false

    var body: some View {
        Text(text)
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(inverse ? Fixer.base : Fixer.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(inverse ? Fixer.text.opacity(0.92) : Fixer.film)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(inverse ? Fixer.base.opacity(0.2) : Fixer.line2, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct FixerPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FixerButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            kind: .primary
        )
    }
}

struct FixerSecondaryButton: ButtonStyle {
    var tint: Color = Fixer.textDim

    func makeBody(configuration: Configuration) -> some View {
        FixerButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            kind: .secondary(tint)
        )
    }
}

private enum FixerButtonKind {
    case primary
    case secondary(Color)
}

/// Keeps the press response consistent and lets Reduce Motion remove the
/// small depth shift without changing the control's visual state.
private struct FixerButtonSurface<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let kind: FixerButtonKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    var body: some View {
        label
            .font(Fixer.sans(kind.isPrimary ? 12.5 : 12, .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind.isPrimary ? 15 : 13)
            .padding(.vertical, 8)
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(border, lineWidth: isFocused ? 1.5 : 1)
            }
            .clipShape(.rect(cornerRadius: 6))
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.975 : 1))
            .offset(y: reduceMotion ? 0 : (isPressed ? 1 : 0))
            .opacity(isEnabled ? 1 : 0.46)
            .onHover { isHovered = $0 }
            .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isHovered)
            .animation(FixerMotion.press(reduceMotion: reduceMotion), value: isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            Fixer.text.opacity(isEnabled ? 1 : 0.72)
        case .secondary(let tint):
            isHovered || isFocused ? Fixer.text : tint
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            if isPressed { Fixer.yellow.opacity(0.74) }
            else if isHovered { Fixer.yellow.opacity(0.86) }
            else { Fixer.yellow }
        case .secondary:
            if isPressed { Fixer.yellowWash.opacity(0.82) }
            else if isHovered || isFocused { Fixer.film.opacity(0.88) }
            else { Fixer.panel.opacity(0) }
        }
    }

    private var border: Color {
        if isFocused { return Fixer.text.opacity(0.72) }
        if kind.isPrimary { return Fixer.yellowDark }
        if isHovered || isPressed { return Fixer.yellowDark.opacity(0.58) }
        return Fixer.line2
    }
}

private extension FixerButtonKind {
    var isPrimary: Bool {
        if case .primary = self { return true }
        return false
    }
}

struct StatusDot: View {
    var color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

struct FixerField<Content: View>: View {
    var borderColor: Color = Fixer.line2
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Fixer.panel)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
