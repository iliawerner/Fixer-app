import AppKit
import SwiftUI
import Testing
import KeyboardShortcuts
@testable import fixer

@Suite(.serialized)
struct ActionDetailTransitionRenderingTests {
    @Test(arguments: [false, true]) @MainActor
    func switchingKeepsChromeOpaqueAndRetargetsOneNativeEditor(isDark: Bool) async throws {
        let suiteName = "ActionDetailTransitionRenderingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsManager(defaults: defaults, hotkeys: TransitionPreviewHotkeys())
        let actions = ["First", "Second", "Latest"].map { name in
            MacroAction(
                name: name,
                shortcutName: KeyboardShortcuts.Name(UUID().uuidString),
                promptTemplate: "\(name) action has its own editable prompt."
            )
        }
        settings.actions = actions
        let selection = TransitionPreviewSelection(actionID: actions[0].id)
        let size = NSSize(width: 594, height: 620)
        let hosting = NSHostingView(
            rootView: TransitionPreviewHost(settings: settings, selection: selection)
                .environment(\.colorScheme, isDark ? .dark : .light)
                .frame(width: size.width, height: size.height)
        )
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        hosting.wantsLayer = true

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = hosting.appearance
        window.backgroundColor = Fixer.baseNS
        window.contentView = hosting
        window.orderBack(nil)
        defer { window.orderOut(nil) }

        try await Task.sleep(for: .milliseconds(180))
        let baseline = try snapshot(hosting, window: window)
        // Empty masthead paper and the gutter beside the form avoid all text,
        // focus rings, and controls. Several x positions catch a sweeping tint.
        let probes = [
            NSPoint(x: 104, y: 20), NSPoint(x: 248, y: 20), NSPoint(x: 410, y: 20),
            NSPoint(x: 572, y: 164), NSPoint(x: 572, y: 326), NSPoint(x: 572, y: 488)
        ]
        let baselineColors = try probes.map { try sample(baseline, at: $0, viewSize: size) }
        // Confirm these probes actually see the two different chrome surfaces.
        #expect(baselineColors[0].maximumDifference(from: baselineColors[3]) > 0.03)
        #expect(nativePromptEditors(in: hosting).map(\.string) == [actions[0].promptTemplate])

        selection.actionID = actions[1].id
        try await Task.sleep(for: .milliseconds(20))
        try assertStableChrome(
            snapshot(hosting, window: window), probes: probes,
            baselineColors: baselineColors, viewSize: size
        )
        #expect(nativePromptEditors(in: hosting).count == 1)

        // Retarget while the first switch is still leaving. The final editor
        // must show the latest request without ever creating a second TextEditor.
        selection.actionID = actions[2].id
        for delay in [20, 25, 30, 40, 60, 100] {
            try await Task.sleep(for: .milliseconds(delay))
            try assertStableChrome(
                snapshot(hosting, window: window), probes: probes,
                baselineColors: baselineColors, viewSize: size
            )
            #expect(nativePromptEditors(in: hosting).count == 1)
        }
        #expect(nativePromptEditors(in: hosting).map(\.string) == [actions[2].promptTemplate])
    }

    @MainActor
    private func snapshot<V: View>(
        _ hosting: NSHostingView<V>, window: NSWindow
    ) throws -> NSBitmapImageRep {
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    private func assertStableChrome(
        _ bitmap: NSBitmapImageRep,
        probes: [NSPoint],
        baselineColors: [TransitionPixel],
        viewSize: NSSize
    ) throws {
        for (point, expected) in zip(probes, baselineColors) {
            let actual = try sample(bitmap, at: point, viewSize: viewSize)
            #expect(actual.alpha >= 0.99)
            #expect(
                actual.maximumDifference(from: expected) <= 0.012,
                "The stationary chrome changed color at \(point): \(expected) → \(actual)"
            )
        }
    }

    private func sample(
        _ bitmap: NSBitmapImageRep, at point: NSPoint, viewSize: NSSize
    ) throws -> TransitionPixel {
        // Median over a small square avoids the decorative half-point grid
        // introducing antialiasing noise into otherwise solid masthead paper.
        var pixels: [TransitionPixel] = []
        for dy in -2...2 {
            for dx in -2...2 {
                let x = Int((point.x + CGFloat(dx)) * CGFloat(bitmap.pixelsWide) / viewSize.width)
                let y = Int((point.y + CGFloat(dy)) * CGFloat(bitmap.pixelsHigh) / viewSize.height)
                let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                pixels.append(TransitionPixel(
                    red: color.redComponent, green: color.greenComponent,
                    blue: color.blueComponent, alpha: color.alphaComponent
                ))
            }
        }
        return TransitionPixel(
            red: pixels.map(\.red).sorted()[12],
            green: pixels.map(\.green).sorted()[12],
            blue: pixels.map(\.blue).sorted()[12],
            alpha: pixels.map(\.alpha).sorted()[12]
        )
    }

    @MainActor
    private func nativePromptEditors(in view: NSView) -> [NSTextView] {
        let current = (view as? NSTextView).flatMap { $0.isFieldEditor ? nil : $0 }
        return (current.map { [$0] } ?? []) + view.subviews.flatMap { nativePromptEditors(in: $0) }
    }
}

private struct TransitionPixel: CustomStringConvertible {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var description: String { "rgba(\(red), \(green), \(blue), \(alpha))" }

    func maximumDifference(from other: Self) -> CGFloat {
        max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
    }
}

@MainActor
private final class TransitionPreviewSelection: ObservableObject {
    @Published var actionID: UUID

    init(actionID: UUID) { self.actionID = actionID }
}

@MainActor
private final class TransitionPreviewHotkeys: HotkeyBinding {
    func unbind(name: KeyboardShortcuts.Name) {}
    func reconcile(actions: [MacroAction]) {}
}

private struct TransitionPreviewHost: View {
    let settings: SettingsManager
    @ObservedObject var selection: TransitionPreviewSelection

    var body: some View {
        ActionDetailMotionShell(
            settings: settings,
            actionID: selection.actionID,
            models: [],
            shortcutRevision: .constant(0),
            onSelectAction: { selection.actionID = $0 },
            onShortcutChanged: {},
            animatesAppearance: false,
            reduceMotion: false
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Fixer.base)
    }
}
