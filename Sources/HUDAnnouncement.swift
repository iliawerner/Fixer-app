import AppKit

/// Receives one spoken announcement for each semantic HUD presentation.
///
/// The sink is injected into `HUDPresentationModel`, keeping previews silent and
/// making announcement frequency testable without enabling VoiceOver.
@MainActor
protocol HUDAnnouncementSinking {
    func announce(_ text: String)
}

/// Posts through the application accessibility element. This asks VoiceOver to
/// speak without making the passive HUD panel key, main, or interactive.
@MainActor
struct SystemHUDAnnouncementSink: HUDAnnouncementSinking {
    func announce(_ text: String) {
        let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.high.rawValue
        ]
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: userInfo
        )
    }
}
