import AppKit
import SwiftUI

/// Owns the single passive feedback panel used by every Action run.
///
/// The panel is deliberately non-activating and click-through. Fixer pastes with
/// a synthetic keystroke, so making this window key or main would redirect the
/// result into Fixer instead of the app where the run began.
@MainActor
final class HUDManager {
    static let shared = HUDManager()

    private var panel: NonActivatingHUDPanel?
    private var hostingView: NSHostingView<RunFeedbackHUDView>?
    private var presentationModel: HUDPresentationModel?
    private var transitionTask: Task<Void, Never>?
    private var busyRestorePresentation: RunFeedbackPresentation?

    private init() {}

    func showWorking(actionName: String) {
        present(.working(actionName: actionName))
    }

    func showVoicePreparing(actionName: String) {
        present(.preparingVoice(actionName: actionName))
    }

    func showVoiceListening(
        actionName: String,
        activationMode: VoiceActivationMode
    ) {
        present(.listening(actionName: actionName, activationMode: activationMode))
    }

    func updateVoiceLevel(_ level: Float) {
        presentationModel?.updateActivityLevel(level)
    }

    func showVoiceFinishing() {
        present(.finishingVoice())
    }

    func showVoiceTranscribing() {
        present(.transcribingVoice())
    }

    func showVoiceCancelling() {
        present(.cancellingVoice())
    }

    func showVoiceApplying(actionName: String) {
        present(.applyingVoice(actionName: actionName))
    }

    func showVoiceInserted() {
        present(.voiceInserted())
    }

    func showCopiedForChangedTarget() {
        present(.copiedForChangedTarget())
    }

    func showHistorySaved(copied: Bool) {
        present(.historySaved(copied: copied))
    }

    func showPasteSent() {
        present(.pasteSent())
    }

    func showVoiceCancelled() {
        present(.voiceCancelled())
    }

    /// A repeated shortcut acknowledges the user without starting another run.
    /// The persistent working state returns after this short interruption.
    func showBusy(actionName: String) {
        busyRestorePresentation = HUDBusyRestorePolicy.presentationToRestore(
            current: presentationModel?.presentation,
            previouslyStored: busyRestorePresentation
        )
        present(
            .busy(actionName: actionName),
            restoreAfterBusy: busyRestorePresentation
        )
    }

    func showSuccess(actionName: String, mode: ActionOutputMode) {
        present(.success(actionName: actionName, mode: mode))
    }

    func showError(_ message: String) {
        present(.error(message))
    }

    func dismiss() {
        busyRestorePresentation = nil
        transitionTask?.cancel()
        transitionTask = nil
        guard let panel, panel.isVisible, let presentationModel else { return }

        presentationModel.beginDismissal()
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(HUDMotion.dismissalDuration))
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
            self?.transitionTask = nil
        }
    }

    private func present(
        _ presentation: RunFeedbackPresentation,
        restoreAfterBusy: RunFeedbackPresentation? = nil
    ) {
        if presentation.phase != .busy {
            busyRestorePresentation = nil
        }
        transitionTask?.cancel()
        transitionTask = nil

        let isFirstPresentation = panel == nil
        let panel = existingOrNewPanel(initialPresentation: presentation)
        let size = HUDLayout.panelSize(for: presentation.phase)

        if !isFirstPresentation, let presentationModel {
            presentationModel.present(presentation)
        }

        panel.setContentSize(size)
        hostingView?.frame = NSRect(origin: .zero, size: size)
        positionOnPointerScreen(panel)
        panel.orderFrontRegardless()

        guard let delay = presentation.dismissAfter else { return }
        transitionTask = Task { [weak self] in
            guard let self else { return }

            if presentation.phase == .busy {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                if AppState.shared.isProcessing {
                    if let restoreAfterBusy {
                        self.present(restoreAfterBusy)
                    } else if let name = AppState.shared.processingActionName {
                        self.present(.working(actionName: name))
                    }
                } else {
                    self.dismiss()
                }
                return
            }

            let visibleDuration = max(0, delay - HUDMotion.dismissalDuration)
            try? await Task.sleep(for: .seconds(visibleDuration))
            guard !Task.isCancelled else { return }
            self.presentationModel?.beginDismissal()

            try? await Task.sleep(for: .seconds(HUDMotion.dismissalDuration))
            guard !Task.isCancelled else { return }
            self.panel?.orderOut(nil)
            self.transitionTask = nil
        }
    }

    /// Creates the AppKit shell only once. Subsequent phases update the stable
    /// observable model so SwiftUI can animate from the outgoing value.
    private func existingOrNewPanel(
        initialPresentation: RunFeedbackPresentation
    ) -> NonActivatingHUDPanel {
        if let panel { return panel }

        let model = HUDPresentationModel(
            presentation: initialPresentation,
            announcementSink: SystemHUDAnnouncementSink()
        )
        let size = HUDLayout.panelSize(for: initialPresentation.phase)
        let hosting = NSHostingView(rootView: RunFeedbackHUDView(model: model))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = HUDPanelFactory.make(size: size)
        panel.contentView = hosting

        self.presentationModel = model
        self.hostingView = hosting
        self.panel = panel
        return panel
    }

    private func positionOnPointerScreen(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let screen else { return }

        panel.setFrameOrigin(
            HUDLayout.panelOrigin(
                panelSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            )
        )
    }
}

/// Repeated Busy acknowledgements must keep the last semantic work phase rather
/// than storing Busy as its own restore target and losing Listening/meter copy.
enum HUDBusyRestorePolicy {
    static func presentationToRestore(
        current: RunFeedbackPresentation?,
        previouslyStored: RunFeedbackPresentation?
    ) -> RunFeedbackPresentation? {
        guard current?.phase == .busy else { return current }
        return previouslyStored
    }
}
