import AppKit
import SwiftUI
import Testing
import KeyboardShortcuts
@testable import fixer

@Suite(.serialized)
struct ActionEditorLayoutTests {
    @Test
    func modelMenuLabelsDisambiguateDuplicateDisplayNames() {
        let first = GeminiModel(
            name: "models/gemini-3.1-flash-image-preview",
            displayName: "Nano Banana"
        )
        let second = GeminiModel(
            name: "models/gemini-3-pro-image-preview",
            displayName: "Nano Banana"
        )

        let firstLabel = ActionEditorDeliverySection.modelMenuLabel(for: first)
        let secondLabel = ActionEditorDeliverySection.modelMenuLabel(for: second)

        #expect(firstLabel == "Nano Banana — gemini-3.1-flash-image-preview")
        #expect(secondLabel == "Nano Banana — gemini-3-pro-image-preview")
        #expect(firstLabel != secondLabel)
    }

    @Test @MainActor
    func actionMastheadHasExactIntrinsicHeight() {
        let action = MacroAction(
            name: "Fix grammar",
            shortcutName: KeyboardShortcuts.Name("layout-header")
        )
        let hosting = NSHostingView(
            rootView: ActionEditorHeader(
                action: .constant(action),
                onDuplicate: {},
                onRequestDelete: {}
            )
            .frame(width: 594)
        )

        hosting.layoutSubtreeIfNeeded()

        #expect(
            abs(hosting.fittingSize.height - WorkspaceChromeMetrics.editorMastheadHeight) <= 0.5
        )
    }

    @Test @MainActor
    func actionMastheadAnchorsTitleAtLeadingInset() throws {
        let action = MacroAction(
            name: "Fix grammar",
            shortcutName: KeyboardShortcuts.Name("layout-header-leading")
        )
        let size = NSSize(width: 594, height: WorkspaceChromeMetrics.editorMastheadHeight)
        let bitmap = try render(
            ActionEditorHeader(
                action: .constant(action),
                onDuplicate: {},
                onRequestDelete: {}
            ),
            size: size
        )

        var firstDarkPixelX: Int?
        let trailingMenuClearance = 80

        // Ignore the one-pixel separator at either vertical edge. The quiet
        // grid remains far above this darkness threshold, so the first dark
        // pixel in the remaining leading plane belongs to the title glyphs.
        for x in 0..<(bitmap.pixelsWide - trailingMenuClearance) {
            for y in 4..<(bitmap.pixelsHigh - 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    continue
                }
                if color.redComponent < 0.36,
                   color.greenComponent < 0.36,
                   color.blueComponent < 0.36 {
                    firstDarkPixelX = x
                    break
                }
            }
            if firstDarkPixelX != nil { break }
        }

        let titleStart = try #require(firstDarkPixelX)
        let backingScale = CGFloat(bitmap.pixelsWide) / size.width
        let titleStartInPoints = CGFloat(titleStart) / backingScale
        #expect(titleStartInPoints >= 18)
        #expect(titleStartInPoints <= 42)
    }

    @Test @MainActor
    func sidebarToolbarStaysOnNativeAxisWithOrWithoutSetupIssue() {
        for issueCount in [0, 3] {
            let hosting = NSHostingView(
                rootView: ActionLibraryTitlebarRow(
                    setupIssueCount: issueCount,
                    onAdd: {},
                    onOpenLibrary: {},
                    onOpenSetup: {},
                    onOpenHistory: {}
                )
                .frame(width: WorkspaceChromeMetrics.sidebarWidth)
            )

            hosting.layoutSubtreeIfNeeded()

            #expect(
                abs(hosting.fittingSize.height - WorkspaceChromeMetrics.headerHeight) <= 0.5
            )
        }
    }

    @Test @MainActor
    func editorKeepsYellowGridMastheadBoundedAndLocalized() throws {
        let suiteName = "ActionEditorLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(
            defaults: defaults,
            hotkeys: ActionEditorPreviewHotkeys()
        )
        let actionID = try #require(settings.actions.first?.id)
        let size = NSSize(width: 594, height: 620)
        let bitmap = try render(
            ActionDetailPane(
                settings: settings,
                actionID: actionID,
                models: [],
                shortcutRevision: .constant(0),
                onSelectAction: { _ in },
                onShortcutChanged: {}
            ),
            size: size
        )

        var signalYellowPixels = 0
        var sampledPixels = 0
        var yellowRows = 0

        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
            var rowYellow = 0
            var rowSamples = 0
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    continue
                }

                sampledPixels += 1
                rowSamples += 1
                if isSignalYellow(color) {
                    signalYellowPixels += 1
                    rowYellow += 1
                }
            }

            if rowSamples > 0, Double(rowYellow) / Double(rowSamples) > 0.55 {
                yellowRows += 1
            }
        }

        let yellowRatio = Double(signalYellowPixels) / Double(sampledPixels)
        let pointsPerSampledRow = Double(size.height) / Double(bitmap.pixelsHigh / 2)
        let yellowBandHeight = Double(yellowRows) * pointsPerSampledRow

        // Character lives in one bounded 100-point masthead. The band must be
        // visibly distinct from the native rail without returning to a giant
        // decorative slab or implying a ruler/progress bar.
        #expect(yellowRatio >= 0.13)
        #expect(yellowRatio <= 0.19)
        #expect(yellowBandHeight >= 96)
        #expect(yellowBandHeight <= 104)
    }

    @Test
    func sidebarTitlebarRowReservesOnlyTheSystemTrafficLightRegion() {
        #expect(WorkspaceChromeMetrics.headerHeight == 40)
        #expect(WorkspaceChromeMetrics.editorMastheadHeight == 100)
        #expect(WorkspaceChromeMetrics.trafficLightClearance >= 86)
        #expect(WorkspaceChromeMetrics.trafficLightClearance <= 92)
        #expect(WorkspaceChromeMetrics.titlebarControlSize == 28)
        #expect(WorkspaceChromeMetrics.mastheadTitleControlHeight >= 38)
        #expect(WorkspaceChromeMetrics.mastheadTitleControlHeight <= 44)
        #expect(WorkspaceChromeMetrics.sidebarWidth == 292)
    }

    @Test
    func promptGeometryStartsUsefulAndStaysBounded() {
        #expect(ActionEditorMetrics.promptMinimumHeight == 160)
        #expect(ActionEditorMetrics.promptDefaultHeight >= 170)
        #expect(ActionEditorMetrics.promptMaximumHeight >= 320)
        #expect(ActionEditorMetrics.promptMaximumHeight <= 380)
        #expect(ActionEditorMetrics.sectionVerticalInset <= 15)
        #expect(ActionEditorMetrics.contentMaximumWidth == 480)
        #expect(ActionEditorMetrics.headerNameMaximumWidth <= 420)
        #expect(ActionEditorMetrics.settingSpacing >= 16)
        #expect(ActionEditorMetrics.settingSpacing <= 24)
    }

    @MainActor
    private func render<V: View>(_ view: V, size: NSSize) throws -> NSBitmapImageRep {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.wantsLayer = true

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = Fixer.baseNS
        window.contentView = hosting
        window.orderBack(nil)
        defer { window.orderOut(nil) }

        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.current.run(until: Date.now.addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    private func isSignalYellow(_ color: NSColor) -> Bool {
        color.redComponent > 0.66
            && color.greenComponent > 0.45
            && color.blueComponent < 0.34
            && color.redComponent > color.blueComponent * 2
    }
}

@MainActor
private final class ActionEditorPreviewHotkeys: HotkeyBinding {
    func unbind(name: KeyboardShortcuts.Name) {}
    func reconcile(actions: [MacroAction]) {}
}
