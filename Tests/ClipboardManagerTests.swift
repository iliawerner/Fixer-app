import AppKit
import Testing
@testable import fixer

/// Named pasteboards and injected keystrokes exercise real restoration without
/// touching the user's clipboard or sending synthetic input to another app.
@MainActor
struct ClipboardManagerTests {
    @Test func pasteRestoresAllRepresentationsAndItems() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("original", forType: .string)
        let richData = Data("{\\rtf1 original}".utf8)
        first.setData(richData, forType: .rtf)
        let second = NSPasteboardItem()
        second.setString("second item", forType: .string)
        pb.writeObjects([first, second])
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            #expect(pb.string(forType: .string) == "result")
        }, pasteSettle: 0.01, modifierTimeout: 0)
        #expect(await manager.paste("result", ifTargetCurrent: { true }))
        #expect(pb.pasteboardItems?.count == 2)
        #expect(pb.pasteboardItems?[0].string(forType: .string) == "original")
        #expect(pb.pasteboardItems?[0].data(forType: .rtf) == richData)
        #expect(pb.pasteboardItems?[1].string(forType: .string) == "second item")
    }

    @Test func emptyOriginalClipboardEndsEmpty() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.clearContents()
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in },
                                       pasteSettle: 0.01, modifierTimeout: 0)
        #expect(await manager.paste("result", ifTargetCurrent: { true }))
        #expect(pb.pasteboardItems?.isEmpty ?? true)
    }

    @Test func newerWriteAfterKeyIsNotOverwrittenDuringRestore() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("original", forType: .string)
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            pb.clearContents()
            pb.setString("newer copy", forType: .string)
        }, pasteSettle: 0.01, modifierTimeout: 0)
        #expect(await manager.paste("result", ifTargetCurrent: { true }))
        #expect(pb.string(forType: .string) == "newer copy")
    }

    @Test func modifierTimeoutDoesNotTouchClipboardOrPostKey() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("original", forType: .string)
        let initialCount = pb.changeCount
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            Issue.record("Held modifiers must prevent Paste")
        }, modifierTimeout: 0.02, readModifierFlags: { .maskCommand })
        #expect(!(await manager.paste("result", ifTargetCurrent: { true })))
        #expect(pb.changeCount == initialCount)
    }

    @Test func copyDuringModifierWaitBecomesRestoreValue() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("old clipboard", forType: .string)
        var checks = 0
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in },
            pasteSettle: 0.01, modifierTimeout: 0.1, readModifierFlags: {
                defer { checks += 1 }
                if checks == 0 {
                    pb.clearContents(); pb.setString("new user copy", forType: .string)
                    return .maskCommand
                }
                return []
            })
        #expect(await manager.paste("result", ifTargetCurrent: { true }))
        #expect(pb.string(forType: .string) == "new user copy")
    }

    @Test func explicitCopyRemainsAndPostsNoKey() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in
            Issue.record("Explicit copy must not paste")
        })
        await manager.copyText("result")
        await manager.restore()
        #expect(pb.string(forType: .string) == "result")
    }

    @Test func historyCopyDuringPasteSettleSurvivesRestoration() async {
        let pb = NSPasteboard(name: .init("fixer-clipboard-\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("previous", forType: .string)
        let (events, continuation) = AsyncStream.makeStream(of: Void.self)
        let manager = ClipboardManager(pasteboard: pb, performKeystroke: { _, _ in continuation.yield() },
                                       pasteSettle: 0.15, modifierTimeout: 0)
        let paste = Task { await manager.paste("automatic result", ifTargetCurrent: { true }) }
        var iterator = events.makeAsyncIterator()
        _ = await iterator.next()
        #expect(await manager.copyText("manual history copy"))
        #expect(await paste.value)
        continuation.finish()
        #expect(pb.string(forType: .string) == "manual history copy")
    }
}
