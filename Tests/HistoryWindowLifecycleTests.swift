import AppKit
import Combine
import SwiftUI
import Testing
@testable import fixer

@MainActor
struct HistoryWindowLifecycleTests {
    @Test
    func cachedWindowCloseStopsOnlyItsOwnPlaybackObserverAndWorksAfterReopen() throws {
        let owner = HistoryWindowFactory.make(rootView: Color.clear, frameAutosaveName: nil)
        let other = HistoryWindowFactory.make(rootView: Color.clear, frameAutosaveName: nil)
        defer {
            owner.close()
            other.close()
        }
        let lifecycle = try #require(owner.delegate as? HistoryWindowLifecycle)
        var isPlaying = true
        var stopCount = 0
        let subscription = lifecycle.willClose.sink {
            isPlaying = false
            stopCount += 1
        }
        defer { subscription.cancel() }

        owner.orderBack(nil)
        other.orderBack(nil)
        other.close()
        #expect(isPlaying)
        #expect(stopCount == 0)

        owner.close()
        #expect(!isPlaying)
        #expect(stopCount == 1)
        #expect(owner.delegate === lifecycle)

        owner.orderBack(nil)
        isPlaying = true
        owner.close()
        #expect(!isPlaying)
        #expect(stopCount == 2)
    }
}
