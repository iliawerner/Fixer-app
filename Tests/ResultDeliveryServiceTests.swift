import AppKit
import Carbon
import Testing
@testable import fixer

@MainActor
struct ResultDeliveryServiceTests {
    @Test func unchangedTargetPastesAndRestoresFreshClipboard() async {
        let pb = NSPasteboard(name: .init("fixer-delivery-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("user copy during request", forType: .string)
        var received: String?
        let clipboard = ClipboardManager(pasteboard: pb, performKeystroke: { key, _ in
            #expect(key == CGKeyCode(kVK_ANSI_V))
            received = pb.string(forType: .string)
        }, pasteSettle: 0.01, modifierTimeout: 0)
        let service = ResultDeliveryService(isCurrent: { _ in true },
            paste: { await clipboard.paste($0, ifTargetCurrent: $1) },
            copy: { _ in Issue.record("Verified paste must not fall back"); return true }, shouldCopy: { true })
        let outcome = await service.deliver("result", to: .init(processIdentifier: 99))
        #expect(outcome == .pasteSent)
        #expect(received == "result")
        #expect(pb.string(forType: .string) == "user copy during request")
    }

    @Test(arguments: [true, false])
    func changedOrUnverifiableTargetObeysClipboardPreference(copyEnabled: Bool) async {
        var copied: [String] = []
        let service = ResultDeliveryService(isCurrent: { _ in false },
            paste: { _, _ in Issue.record("Changed target must not paste"); return true },
            copy: { copied.append($0); return true }, shouldCopy: { copyEnabled })
        for target: VoiceInsertionTarget? in [nil, .init(processIdentifier: 99)] {
            let outcome = await service.deliver("result", to: target)
            #expect(outcome == (copyEnabled ? .copied : .historyOnly))
        }
        #expect(copied.count == (copyEnabled ? 2 : 0))
    }

    @Test func targetChangeDuringClipboardStagingRestoresClipboardWithoutKey() async {
        let pb = NSPasteboard(name: .init("fixer-delivery-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("original", forType: .string)
        let clipboard = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            Issue.record("Late target change must not post a key")
        }, pasteSettle: 0.01, modifierTimeout: 0)
        var checks = 0
        let service = ResultDeliveryService(isCurrent: { _ in
            checks += 1
            return checks < 3
        }, paste: { await clipboard.paste($0, ifTargetCurrent: $1) },
        copy: { _ in Issue.record("Disabled fallback must not copy"); return true }, shouldCopy: { false })
        #expect(await service.deliver("result", to: .init(processIdentifier: 99)) == .historyOnly)
        #expect(checks == 3)
        #expect(pb.string(forType: .string) == "original")
    }

    @Test func concurrentClipboardWriteBeforeKeyWins() async {
        let pb = NSPasteboard(name: .init("fixer-delivery-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("original", forType: .string)
        let clipboard = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            Issue.record("Clipboard replaced before paste; no key should be sent")
        }, pasteSettle: 0.01, modifierTimeout: 0)
        var checks = 0
        let didPaste = await clipboard.paste("result", ifTargetCurrent: {
            checks += 1
            if checks == 2 { pb.clearContents(); pb.setString("new user copy", forType: .string) }
            return true
        })
        #expect(!didPaste)
        #expect(pb.string(forType: .string) == "new user copy")
    }

    @Test func cancellationWhileModifiersHeldNeverPostsOrCopies() async {
        let pb = NSPasteboard(name: .init("fixer-delivery-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("original", forType: .string)
        let (events, continuation) = AsyncStream.makeStream(of: Void.self)
        let clipboard = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            Issue.record("Cancelled delivery must not post a key")
        }, modifierTimeout: 1, readModifierFlags: { continuation.yield(); return .maskCommand })
        let service = ResultDeliveryService(isCurrent: { _ in true },
            paste: { await clipboard.paste($0, ifTargetCurrent: $1) },
            copy: { _ in Issue.record("Cancelled delivery must not copy"); return true }, shouldCopy: { true })
        let task = Task { await service.deliver("result", to: .init(processIdentifier: 99)) }
        var iterator = events.makeAsyncIterator()
        _ = await iterator.next()
        task.cancel()
        #expect(await task.value == .historyOnly)
        continuation.finish()
        #expect(pb.string(forType: .string) == "original")
    }

    @Test func clipboardFailureDoesNotClaimResultWasCopied() async {
        let service = ResultDeliveryService(copy: { _ in false }, shouldCopy: { true })
        #expect(await service.deliver("saved result", to: nil) == .historyOnly)
    }
}
