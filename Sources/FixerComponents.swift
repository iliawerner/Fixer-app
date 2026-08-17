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

struct KodakEdge: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        MonoLabel(text, size: 8.5, tracking: 2, color: Fixer.yellowDark, weight: .semibold)
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

/// Quiet technical grid used only on the yellow action header.
struct SignalGrid: View {
    var spacing: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            var path = Path()
            stride(from: CGFloat.zero, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat.zero, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Fixer.text.opacity(0.065)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Compact data marks

struct Keycap: View {
    let text: String
    var inverse = false

    var body: some View {
        Text(text)
            .font(Fixer.mono(11, .semibold))
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

struct SetKeyChip: View {
    var body: some View {
        MonoLabel("Set shortcut", size: 8.5, tracking: 0.8, color: Fixer.yellowDark, weight: .semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .foregroundStyle(Fixer.yellowDark)
            )
    }
}

struct PromptPreview: View {
    let prompt: String
    var size: CGFloat = 12.5
    var color: Color = Fixer.textDim

    var body: some View {
        let parts = prompt.components(separatedBy: "{text}")
        return parts.enumerated().reduce(Text("")) { acc, pair in
            let (index, part) = pair
            var text = acc + Text(part).font(Fixer.sans(size)).foregroundColor(color)
            if index < parts.count - 1 {
                text = text + Text("{text}")
                    .font(Fixer.mono(size - 1, .semibold))
                    .foregroundColor(Fixer.yellowDark)
            }
            return text
        }
    }
}

// MARK: - Controls

struct FixerSwitch: View {
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil

    var body: some View {
        Button {
            let next = !isOn
            isOn = next
            onChange?(next)
        } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOn ? Fixer.yellow : Fixer.film)
                .frame(width: 36, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isOn ? Fixer.yellowDark : Fixer.line2, lineWidth: 1)
                )
                .overlay(alignment: isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isOn ? Fixer.text : Fixer.muted2)
                        .frame(width: 12, height: 12)
                        .padding(4)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isOn)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct FixerPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fixer.sans(12.5, .semibold))
            .foregroundStyle(Fixer.text)
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Fixer.yellow.opacity(configuration.isPressed ? 0.78 : 1))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Fixer.yellowDark, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FixerSecondaryButton: ButtonStyle {
    var tint: Color = Fixer.textDim

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fixer.sans(12, .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Fixer.panel.opacity(configuration.isPressed ? 0.55 : 0))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Fixer.line2, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StatusDot: View {
    var color: Color
    var pulsing = false
    var glow = false
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: glow ? color.opacity(0.4) : .clear, radius: glow ? 3 : 0)
            .opacity(pulsing ? (on ? 1 : 0.3) : 1)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
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

// MARK: - Legacy film container

/// Kept as a neutral ruled container for older call sites. V2 no longer presents
/// the action library as film stock.
struct FilmFrame<Content: View>: View {
    var edgeCode: String
    var edgeTrailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                KodakEdge(edgeCode)
                Spacer()
                if let edgeTrailing { KodakEdge(edgeTrailing) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Fixer.film)

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .background(Fixer.panel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Fixer.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Lightweight texture

struct Grain: View {
    var intensity: Double = 0.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                var seed = UInt64(bitPattern: Int64(time * 10)) &* 0x9E3779B97F4A7C15
                func random() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double(seed >> 33) / Double(UInt64(1) << 31)
                }

                let dots = Int(size.width * size.height / 380)
                for _ in 0..<dots {
                    let point = CGPoint(x: random() * size.width, y: random() * size.height)
                    let alpha = random() * 0.18 * intensity
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 0.8, height: 0.8)),
                        with: .color(Fixer.text.opacity(alpha))
                    )
                }
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}
