import SwiftUI

/// Mutable bridge between the AppKit HUD window and its persistent SwiftUI tree.
///
/// The model identity stays stable for the lifetime of the panel. Replacing the
/// `NSHostingView` for every phase would turn a direct status update into a blink.
@MainActor
final class HUDPresentationModel: ObservableObject {
    @Published private(set) var presentation: RunFeedbackPresentation
    @Published private(set) var revision = 0
    @Published private(set) var isVisible = true
    private let announcementSink: (any HUDAnnouncementSinking)?

    init(
        presentation: RunFeedbackPresentation,
        announcementSink: (any HUDAnnouncementSinking)? = nil
    ) {
        self.presentation = presentation
        self.announcementSink = announcementSink
        announce(presentation)
    }

    /// Publishes a new semantic phase while preserving the surrounding panel.
    func present(_ next: RunFeedbackPresentation) {
        presentation = next
        revision += 1
        isVisible = true
        announce(next)
    }

    /// Starts the view-owned exit animation before AppKit orders the panel out.
    func beginDismissal() {
        isVisible = false
    }

    private func announce(_ presentation: RunFeedbackPresentation) {
        announcementSink?.announce(presentation.accessibilityAnnouncement)
    }
}
