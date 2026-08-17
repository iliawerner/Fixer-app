import SwiftUI
import AppKit

/// A compact, passive run annotation. The panel never becomes key or main, so
/// the originating application remains the target for Fixer's synthetic paste.
@MainActor
final class HUDManager {
    static let shared = HUDManager()

    private var panel: NonActivatingHUDPanel?
    private var transitionTask: Task<Void, Never>?

    private init() {}

    func showWorking(actionName: String) {
        present(.working(actionName: actionName))
    }

    /// A repeated shortcut acknowledges the user without starting another run.
    /// The persistent working state returns after this short interruption.
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
        positionOnPointerScreen(panel)
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
        presentation.phase == .error
            ? NSSize(width: 380, height: 132)
            : NSSize(width: 368, height: 88)
    }

    private func existingOrNewPanel() -> NonActivatingHUDPanel {
        if let panel { return panel }

        let panel = NonActivatingHUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 368, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.panel = panel
        return panel
    }

    private func positionOnPointerScreen(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let screen else { return }

        let origin = HUDLayout.panelOrigin(
            panelSize: panel.frame.size,
            visibleFrame: screen.visibleFrame
        )
        panel.setFrameOrigin(origin)
    }
}

/// A defensive second line of protection beyond `.nonactivatingPanel`.
private final class NonActivatingHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Mended rule

/// A slim technical annotation rail. The fixed diagonal repair mark identifies
/// Fixer; only its perforation dots move while work is indeterminate, so the HUD
/// never pretends to know completion progress.
struct RepairHUDView: View {
    let presentation: RunFeedbackPresentation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var exiting = false

    private var isError: Bool { presentation.phase == .error }
    private var railSize: CGSize {
        isError
            ? CGSize(width: 360, height: 112)
            : CGSize(width: 328, height: 64)
    }

    var body: some View {
        rail
            .frame(width: railSize.width, height: railSize.height)
            .padding(.bottom, 8)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
            .opacity(exiting ? 0 : (revealed ? 1 : 0))
            .offset(y: reduceMotion ? 0 : (revealed ? 0 : 6))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(presentation.label). \(presentation.title). \(presentation.detail)"
            )
            .onAppear {
                withAnimation(appearanceAnimation) {
                    revealed = true
                }
            }
            .task {
                guard presentation.phase == .success || presentation.phase == .error,
                      let delay = presentation.dismissAfter else { return }
                let fadeDuration = presentation.phase == .success ? 0.12 : 0.16
                let wait = max(0, delay - fadeDuration)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: fadeDuration)) {
                    exiting = true
                }
            }
    }

    private var rail: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Fixer.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Fixer.line2.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 2)

            MendedRepairMark(phase: presentation.phase)
                .offset(x: -6)

            VStack(alignment: .leading, spacing: isError ? 5 : 2) {
                HStack(spacing: 8) {
                    Text(presentation.label)
                        .font(Fixer.mono(9, .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Fixer.yellow)
                    Spacer(minLength: 6)
                    Text("FIXER 2")
                        .font(Fixer.mono(7.5, .medium))
                        .tracking(1.1)
                        .foregroundStyle(Fixer.muted2)
                }

                Text(presentation.title)
                    .font(Fixer.sans(13.5, .semibold))
                    .foregroundStyle(Fixer.base)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(presentation.detail)
                    .font(Fixer.sans(isError ? 11.5 : 10.5, .medium))
                    .foregroundStyle(isError ? Fixer.base.opacity(0.9) : Fixer.muted2)
                    .lineLimit(isError ? 3 : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if isError {
                    Spacer(minLength: 0)
                    Text("SAVED IN FIXER MENU")
                        .font(Fixer.mono(7.5, .medium))
                        .tracking(1)
                        .foregroundStyle(Fixer.muted2)
                }
            }
            .padding(.leading, 42)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
        }
    }

    private var appearanceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.08)
            : .timingCurve(0.2, 0, 0, 1, duration: 0.14)
    }
}

private struct MendedRepairMark: View {
    let phase: RunFeedbackPresentation.Phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var alternateDots = false
    @State private var inverted = false

    private var markColor: Color {
        phase == .busy && inverted ? Fixer.base : Fixer.yellow
    }

    private var cutoutColor: Color {
        phase == .busy && inverted ? Fixer.yellow : Fixer.base
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(markColor)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(cutoutColor.opacity(0.28))
                .frame(width: 12, height: 8)

            HStack(spacing: 14) {
                Circle()
                    .fill(cutoutColor)
                    .frame(width: 2.5, height: 2.5)
                    .opacity(leftDotOpacity)
                Circle()
                    .fill(cutoutColor)
                    .frame(width: 2.5, height: 2.5)
                    .opacity(rightDotOpacity)
            }
            .frame(width: 25)
        }
        .frame(width: 34, height: 12)
        .rotationEffect(.degrees(32))
        .onAppear {
            guard !reduceMotion else { return }
            switch phase {
            case .working:
                withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                    alternateDots = true
                }
            case .busy:
                withAnimation(.easeInOut(duration: 0.18)) {
                    inverted = true
                }
            case .success, .error:
                break
            }
        }
    }

    private var leftDotOpacity: Double {
        guard phase == .working, !reduceMotion else { return 1 }
        return alternateDots ? 1 : 0.4
    }

    private var rightDotOpacity: Double {
        guard phase == .working, !reduceMotion else { return 1 }
        return alternateDots ? 0.4 : 1
    }
}
