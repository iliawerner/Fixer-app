import SwiftUI
import AppKit

/// A compact repair ticket that never activates the app. Focus must remain in
/// the source application or the synthetic paste would land in Fixer itself.
@MainActor
final class HUDManager {
    static let shared = HUDManager()

    private var panel: NSPanel?
    private var transitionTask: Task<Void, Never>?

    private init() {}

    func showWorking(actionName: String) {
        present(.working(actionName: actionName))
    }

    /// Repeated shortcuts are acknowledged rather than silently ignored. After
    /// the brief nudge, restore the long-running state if the request is active.
    func showBusy(actionName: String) {
        present(.busy(actionName: actionName), restoreWorkingAfter: true)
    }

    func showSuccess(actionName: String, mode: ActionOutputMode) {
        present(.success(actionName: actionName, mode: mode))
    }

    func showError(_ message: String) {
        present(.error(message))
    }

    func dismiss() {
        transitionTask?.cancel()
        transitionTask = nil
        panel?.orderOut(nil)
    }

    private func present(
        _ presentation: RunFeedbackPresentation,
        restoreWorkingAfter: Bool = false
    ) {
        transitionTask?.cancel()
        transitionTask = nil

        let size = panelSize(for: presentation)
        let hosting = NSHostingView(rootView: RepairHUDView(presentation: presentation))
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = existingOrNewPanel()
        panel.contentView = hosting
        panel.setContentSize(size)
        positionNearBottomCenter(panel)
        panel.orderFrontRegardless()

        guard let delay = presentation.dismissAfter else { return }
        transitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }

            if restoreWorkingAfter,
               AppState.shared.isProcessing,
               let name = AppState.shared.processingActionName {
                self.present(.working(actionName: name))
            } else {
                self.panel?.orderOut(nil)
            }
        }
    }

    private func panelSize(for presentation: RunFeedbackPresentation) -> NSSize {
        switch presentation.phase {
        case .error:
            return NSSize(width: 370, height: 100)
        case .working, .busy, .success:
            return NSSize(width: 360, height: 88)
        }
    }

    private func existingOrNewPanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // the SwiftUI ticket owns its deliberate offset shadow
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.panel = panel
        return panel
    }

    private func positionNearBottomCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.minY + 118
            )
        )
    }
}

// MARK: - Repair ticket

struct RepairHUDView: View {
    let presentation: RunFeedbackPresentation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 0) {
            RepairIndicator(phase: presentation.phase)
                .frame(width: 67)
                .frame(maxHeight: .infinity)
                .background(indicatorBackground)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    MonoLabel(
                        presentation.label,
                        size: 8.5,
                        tracking: 1.25,
                        color: labelColor,
                        weight: .bold
                    )
                    Spacer(minLength: 6)
                    Text("FIXER 2")
                        .font(Fixer.mono(7.5, .medium))
                        .tracking(1.1)
                        .foregroundStyle(Fixer.muted2)
                }

                Text(presentation.title)
                    .font(Fixer.sans(13.5, .semibold))
                    .foregroundStyle(Fixer.text)
                    .lineLimit(1)

                Text(presentation.detail)
                    .font(Fixer.sans(10.5))
                    .foregroundStyle(presentation.phase == .error ? Fixer.safeText : Fixer.muted)
                    .lineLimit(presentation.phase == .error ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)

                RepairTrack(phase: presentation.phase)
                    .frame(height: 3)
                    .padding(.top, 3)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .padding(.vertical, 11)
            .opacity(revealed ? 1 : 0.25)
            .offset(x: reduceMotion ? 0 : (revealed ? 0 : -4))
        }
        .background(Fixer.base, in: RepairTicketShape())
        .overlay(RepairTicketShape().stroke(Fixer.text.opacity(0.88), lineWidth: 1))
        .background {
            RepairTicketShape()
                .fill(Fixer.text.opacity(0.17))
                .offset(x: 3, y: 3)
        }
        .padding(.trailing, 4)
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.label). \(presentation.title). \(presentation.detail)")
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    revealed = true
                }
            }
        }
    }

    private var indicatorBackground: Color {
        switch presentation.phase {
        case .working, .busy, .success:
            return Fixer.yellow
        case .error:
            return Fixer.warningWash
        }
    }

    private var labelColor: Color {
        presentation.phase == .error ? Fixer.safeText : Fixer.yellowDark
    }
}

/// A paper ticket with two clipped corners. It feels like a small piece of the
/// workspace instead of a generic rounded toast.
private struct RepairTicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = 8
        var path = Path()
        path.move(to: CGPoint(x: cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Broken-to-aligned motion

private struct RepairIndicator: View {
    let phase: RunFeedbackPresentation.Phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false

    private var seamOffset: CGFloat {
        switch phase {
        case .working, .busy:
            return active ? 0 : 4
        case .success:
            return active ? 0 : 5
        case .error:
            return 5
        }
    }

    private var markOffset: CGFloat {
        switch phase {
        case .working:
            return active ? 9 : -9
        case .busy:
            return active ? 6 : -6
        case .success, .error:
            return 0
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 9) {
                Capsule()
                    .fill(Fixer.text)
                    .frame(width: 16, height: 2)
                    .offset(y: -seamOffset)
                Capsule()
                    .fill(Fixer.text)
                    .frame(width: 16, height: 2)
                    .offset(y: seamOffset)
            }

            if phase == .error {
                VStack(spacing: 2) {
                    Capsule().fill(Fixer.safeText).frame(width: 2, height: 10)
                    Circle().fill(Fixer.safeText).frame(width: 2.5, height: 2.5)
                }
            } else {
                RepairMark(fill: Fixer.base, ink: Fixer.text)
                    .frame(width: 30, height: 22)
                    .offset(x: markOffset)
                    .rotationEffect(.degrees(phase == .success ? 0 : (active ? 8 : -8)))
            }
        }
        .onAppear {
            guard !reduceMotion else {
                active = phase == .success
                return
            }

            switch phase {
            case .working:
                withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                    active = true
                }
            case .busy:
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    active = true
                }
            case .success:
                withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                    active = true
                }
            case .error:
                active = false
            }
        }
    }
}

private struct RepairTrack: View {
    let phase: RunFeedbackPresentation.Phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Fixer.line).frame(height: 2)

                Rectangle()
                    .fill(trackColor)
                    .frame(width: width(for: geometry.size.width), height: 2)
                    .offset(x: offset(for: geometry.size.width))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            guard !reduceMotion else {
                active = phase == .success
                return
            }

            switch phase {
            case .working:
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    active = true
                }
            case .busy:
                withAnimation(.linear(duration: 0.42).repeatForever(autoreverses: false)) {
                    active = true
                }
            case .success:
                withAnimation(.easeOut(duration: 0.34)) {
                    active = true
                }
            case .error:
                active = false
            }
        }
    }

    private var trackColor: Color {
        phase == .error ? Fixer.safeText : Fixer.yellowDark
    }

    private func width(for available: CGFloat) -> CGFloat {
        switch phase {
        case .working, .busy:
            return max(28, available * 0.22)
        case .success:
            return active ? available : 0
        case .error:
            return min(34, available)
        }
    }

    private func offset(for available: CGFloat) -> CGFloat {
        switch phase {
        case .working, .busy:
            let segment = max(28, available * 0.22)
            return reduceMotion ? (available - segment) / 2 : (active ? available : -segment)
        case .success, .error:
            return 0
        }
    }
}
