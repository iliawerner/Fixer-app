import SwiftUI
import AppKit

/// A small, non-activating on-screen HUD styled as a darkroom frame being
/// developed: film grain, a red safelight, and the result "emerging" from blur.
/// It must never steal key focus, otherwise the synthetic Cmd+V would land in our
/// window instead of the target app — hence the non-activating panel.
@MainActor
final class HUDManager {
    static let shared = HUDManager()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func showWorking() {
        present(HUDView(kind: .working, message: "Passing through the developer…"), autoHideAfter: nil)
    }

    func showSuccess() {
        present(HUDView(kind: .success, message: "Developed & fixed in place"), autoHideAfter: 1.3)
    }

    func showError(_ message: String) {
        present(HUDView(kind: .error, message: message), autoHideAfter: 4.5)
    }

    func dismiss() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
    }

    private func present<V: View>(_ view: V, autoHideAfter: TimeInterval?) {
        hideTask?.cancel()
        hideTask = nil

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 78)

        let panel = existingOrNewPanel()
        panel.contentView = hosting
        let fitting = hosting.fittingSize
        panel.setContentSize(fitting == .zero ? NSSize(width: 320, height: 78) : fitting)
        positionNearBottomCenter(panel)
        panel.orderFrontRegardless() // show without activating / stealing focus

        if let autoHideAfter {
            hideTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(autoHideAfter * 1_000_000_000))
                if !Task.isCancelled { self?.panel?.orderOut(nil) }
            }
        }
    }

    private func existingOrNewPanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.panel = panel
        return panel
    }

    private func positionNearBottomCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 120
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct HUDView: View {
    enum Kind { case working, success, error }
    let kind: Kind
    let message: String

    @State private var developed = false

    private var accent: Color {
        switch kind {
        case .working: return Fixer.safelight
        case .success: return Fixer.amber
        case .error:   return Fixer.safeText
        }
    }
    private var label: String {
        switch kind {
        case .working: return "fixer · developing"
        case .success: return "fixer · fixed"
        case .error:   return "fixer · misfire"
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            lamp
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                MonoLabel(label, size: 8.5, tracking: 1.8, color: accent, weight: .semibold)
                Text(message)
                    .font(Fixer.sans(13, .medium))
                    .foregroundStyle(Fixer.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    // Result "emerges" from the developer: blurred + faint, then sharp.
                    .blur(radius: developed ? 0 : 6)
                    .opacity(developed ? 1 : 0.12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(minWidth: 230, maxWidth: 360, alignment: .leading)
        .background(Fixer.base, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            Grain(intensity: kind == .working ? 0.8 : 0.4)
                .opacity(kind == .working ? 1 : (developed ? 0.2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 3)
                .shadow(color: accent.opacity(0.7), radius: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.vertical, 7)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Fixer.line2, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { developed = true }
        }
    }

    @ViewBuilder
    private var lamp: some View {
        switch kind {
        case .working:
            StatusDot(color: accent, pulsing: true, glow: true).frame(width: 11, height: 11)
        case .success:
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(accent)
        }
    }
}
