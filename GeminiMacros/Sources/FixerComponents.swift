import SwiftUI

// MARK: - Micro label (uppercase monospaced)

struct MonoLabel: View {
    let text: String
    var size: CGFloat = 9
    var tracking: CGFloat = 1.8
    var color: Color = Fixer.muted
    var weight: Font.Weight = .regular

    init(_ text: String, size: CGFloat = 9, tracking: CGFloat = 1.8, color: Color = Fixer.muted, weight: Font.Weight = .regular) {
        self.text = text; self.size = size; self.tracking = tracking; self.color = color; self.weight = weight
    }

    var body: some View {
        Text(text.uppercased())
            .font(Fixer.mono(size, weight))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

/// Kodak-style yellow edge marking.
struct KodakEdge: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        MonoLabel(text, size: 8.5, tracking: 2, color: Fixer.kodak, weight: .semibold)
    }
}

// MARK: - Keycap chip (film keycap)

struct Keycap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Fixer.mono(12, .semibold))
            .foregroundStyle(Fixer.text)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Fixer.film)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Fixer.line2, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Amber dashed "SET KEY" placeholder shown when an action has no shortcut.
struct SetKeyChip: View {
    var body: some View {
        MonoLabel("Set key", size: 9, tracking: 1, color: Fixer.amber, weight: .semibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .foregroundStyle(Fixer.amber)
            )
    }
}

// MARK: - {text} token highlight

/// Renders a prompt string with `{text}` shown as an amber token.
struct PromptPreview: View {
    let prompt: String
    var size: CGFloat = 12.5
    var color: Color = Fixer.textDim

    var body: some View {
        let parts = prompt.components(separatedBy: "{text}")
        return parts.enumerated().reduce(Text("")) { acc, pair in
            let (i, part) = pair
            var t = acc + Text(part).font(Fixer.sans(size)).foregroundColor(color)
            if i < parts.count - 1 {
                t = t + Text("{text}")
                    .font(Fixer.mono(size - 1, .semibold))
                    .foregroundColor(Fixer.amber)
            }
            return t
        }
    }
}

// MARK: - Safelight switch

struct FixerSwitch: View {
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil

    var body: some View {
        Button {
            let next = !isOn
            isOn = next
            onChange?(next)
        } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isOn ? Fixer.safelight : Fixer.line)
                .frame(width: 34, height: 18)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isOn ? Fixer.text : Fixer.muted2)
                        .frame(width: 14, height: 14)
                        .padding(2)
                }
                .shadow(color: isOn ? Fixer.safelight.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isOn)
    }
}

// MARK: - Buttons

struct FixerPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fixer.mono(9.5, .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Fixer.base)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Fixer.text.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct FixerSecondaryButton: ButtonStyle {
    var tint: Color = Fixer.textDim
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fixer.mono(9.5, .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Fixer.film.opacity(configuration.isPressed ? 0.6 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Fixer.line2, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Status dot (safelight lamp)

struct StatusDot: View {
    var color: Color
    var pulsing: Bool = false
    var glow: Bool = false
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: glow ? color.opacity(0.8) : .clear, radius: glow ? 4 : 0)
            .opacity(pulsing ? (on ? 1 : 0.28) : 1)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

// MARK: - Inset field container

struct FixerField<Content: View>: View {
    var borderColor: Color = Fixer.line2
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Fixer.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Film sprocket row

struct SprocketRow: View {
    var body: some View {
        GeometryReader { geo in
            let hole: CGFloat = 8
            let gap: CGFloat = 7
            let count = max(1, Int((geo.size.width + gap) / (hole + gap)))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Fixer.base)
                        .frame(width: hole, height: 6)
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
        .frame(height: 6)
    }
}

/// A 35mm film-strip frame: sprocket rails top and bottom, a Kodak edge code,
/// wrapping arbitrary content on the film surface.
struct FilmFrame<Content: View>: View {
    var edgeCode: String
    var edgeTrailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            rail(top: true)
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            rail(top: false)
        }
        .background(Fixer.film)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Fixer.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func rail(top: Bool) -> some View {
        HStack(spacing: 10) {
            if top {
                KodakEdge(edgeCode)
                Spacer(minLength: 8)
                SprocketRow().frame(maxWidth: 120)
            } else {
                SprocketRow().frame(maxWidth: 120)
                Spacer(minLength: 8)
                if let edgeTrailing { KodakEdge(edgeTrailing) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Fixer.base.opacity(0.55))
    }
}

// MARK: - Animated film grain

/// A lightweight animated grain overlay (darkroom development texture).
struct Grain: View {
    var intensity: Double = 0.5
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                var seed = UInt64(bitPattern: Int64(t * 12)) &* 0x9E3779B97F4A7C15
                func rnd() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double(seed >> 33) / Double(UInt64(1) << 31)
                }
                let dots = Int(size.width * size.height / 260)
                for _ in 0..<dots {
                    let x = rnd() * size.width
                    let y = rnd() * size.height
                    let a = rnd() * 0.5 * intensity
                    let s = 0.6 + rnd() * 1.1
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                             with: .color(.white.opacity(a)))
                }
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}
