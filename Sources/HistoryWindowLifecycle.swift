import AppKit
import Combine
import SwiftUI

/// Each History window owns one close signal. The hosting view retains this
/// delegate through its environment, while NSWindow keeps only a weak delegate.
@MainActor
final class HistoryWindowLifecycle: NSObject, NSWindowDelegate {
    let willClose = PassthroughSubject<Void, Never>()

    func windowWillClose(_ notification: Notification) {
        willClose.send()
    }
}
