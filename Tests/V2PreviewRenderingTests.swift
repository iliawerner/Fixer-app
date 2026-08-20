import AppKit
import SwiftUI
import Testing
import KeyboardShortcuts
@testable import fixer

/// Renders real SwiftUI/AppKit output on the macOS CI runner. PNGs are saved
/// to the configured preview directory and emitted in CI logs so design changes
/// have render evidence instead of only a successful compile.
@Suite(.serialized)
struct V2PreviewRenderingTests {
    @Test @MainActor
    func rendersWorkspaceAndRunFeedback() async throws {
        let configuredPreviewPath = ProcessInfo.processInfo.environment["FIXER_PREVIEW_DIR"]
            .flatMap { $0.isEmpty ? nil : $0 }
        let previewRoot = URL(
            fileURLWithPath: configuredPreviewPath
                ?? (NSTemporaryDirectory() + "/fixer-v2-previews"),
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: previewRoot,
            withIntermediateDirectories: true
        )

        let suiteName = "V2PreviewRenderingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(
            defaults: defaults,
            hotkeys: PreviewHotkeyBinding()
        )
        let appState = AppState()
        let provider = ProviderSetupController(
            keyStore: PreviewAPIKeyStore(value: "preview-only"),
            modelLoader: {
                [GeminiModel(name: "models/gemini-3.6-flash", displayName: "Gemini 3.6 Flash")]
            }
        )
        // Seed the catalog before hosting the workspace. Relying on onAppear
        // made an otherwise valid PNG capture the transient raw-ID fallback,
        // so the design evidence did not exercise the friendly model picker.
        provider.fetchModels()
        for _ in 0..<20 where provider.isLoadingModels {
            await Task.yield()
        }
        #expect(provider.availableModels.count == 1)

        settings.actions = [
            MacroAction.dictation(),
            MacroAction(
                name: "Fix grammar",
                shortcutName: KeyboardShortcuts.Name("preview-fix-grammar"),
                promptTemplate: "Fix grammar and make it sound simple and natural: {text}. Return only the corrected text.",
                modelName: "models/gemini-3.6-flash",
                outputMode: .replace
            ),
            MacroAction(
                name: "Make concise",
                shortcutName: KeyboardShortcuts.Name("preview-make-concise"),
                promptTemplate: "Make this shorter without losing meaning: {text}",
                modelName: "models/gemini-3.6-flash",
                outputMode: .replace
            ),
            MacroAction(
                name: "Translate to English",
                shortcutName: KeyboardShortcuts.Name("preview-translate"),
                promptTemplate: "Translate to natural English: {text}",
                modelName: "models/gemini-2.5-pro",
                outputMode: .append,
                isEnabled: false
            )
        ]
        appState.accessibilityGranted = false

        let workspaceCases: [WorkspaceRenderCase] = [
            .init(filename: "workspace-default.png", size: WorkspaceWindowMetrics.defaultSize),
            .init(filename: "workspace-minimum.png", size: WorkspaceWindowMetrics.minimumSize),
            .init(filename: "workspace-expanded.png", size: .init(width: 1440, height: 900))
        ]

        for renderCase in workspaceCases {
            try render(
                SettingsView(
                    settings: settings,
                    appState: appState,
                    provider: provider,
                    refreshAccessibilityOnAppear: false
                )
                .frame(width: renderCase.size.width, height: renderCase.size.height),
                size: renderCase.size,
                to: previewRoot.appendingPathComponent(renderCase.filename),
                settleFor: 0.95
            )
        }

        let splashSize = NSSize(width: 576, height: 456)
        try render(
            SplashView(autoDismiss: false, presentation: .settled, onDismiss: {})
                .frame(width: splashSize.width, height: splashSize.height),
            size: splashSize,
            to: previewRoot.appendingPathComponent("splash-settled.png"),
            settleFor: 0.05,
            windowBackground: .clear,
            validate: { bitmap in
                try validateSettledSplash(bitmap, stageSize: splashSize)
            }
        )

        let feedback: [(String, RunFeedbackPresentation, Float)] = [
            (
                "feedback-listening.png",
                .listening(actionName: "Dictation", activationMode: .toggle),
                0.68
            ),
            ("feedback-working.png", .working(actionName: "Fix grammar"), 0),
            ("feedback-success.png", .success(actionName: "Fix grammar", mode: .replace), 0),
            ("feedback-error.png", .error("No text selected. Select text, then trigger the shortcut."), 0)
        ]

        for (filename, presentation, activityLevel) in feedback {
            let size = HUDLayout.panelSize(for: presentation.phase)
            try render(
                HUDStatusPanel(
                    presentation: presentation,
                    revision: 0,
                    reduceMotion: false,
                    activityLevel: activityLevel
                )
                .frame(width: size.width, height: size.height),
                size: size,
                to: previewRoot.appendingPathComponent(filename),
                settleFor: 0.1,
                windowBackground: .clear,
                validate: { bitmap in
                    try validateHUDCard(
                        bitmap,
                        panelSize: size,
                        cardSize: HUDLayout.cardSize(for: presentation.phase),
                        phase: presentation.phase
                    )
                }
            )
        }

        let reducedMotionPresentation = RunFeedbackPresentation.working(
            actionName: "Fix grammar"
        )
        let reducedMotionSize = HUDLayout.panelSize(for: reducedMotionPresentation.phase)
        let reducedMotionCardSize = HUDLayout.cardSize(
            for: reducedMotionPresentation.phase
        )
        try render(
            HUDStatusPanel(
                presentation: reducedMotionPresentation,
                revision: 0,
                reduceMotion: true
            )
            .frame(width: reducedMotionSize.width, height: reducedMotionSize.height),
            size: reducedMotionSize,
            to: previewRoot.appendingPathComponent("feedback-working-reduced-motion.png"),
            settleFor: 0.5,
            windowBackground: .clear,
            validate: { bitmap in
                try validateHUDCard(
                    bitmap,
                    panelSize: reducedMotionSize,
                    cardSize: reducedMotionCardSize,
                    phase: reducedMotionPresentation.phase
                )
            }
        )

        // macOS 14 does not honor a programmatic Dynamic Type override for
        // semantic SwiftUI fonts. Long, multi-line copy exercises the same
        // intrinsic-height path while the environment is also set for newer OSes.
        let largeTextPresentation = RunFeedbackPresentation(
            phase: .error,
            label: "Error",
            title: "Accessibility permission is required before Fixer can process selected text in another application",
            detail: "Open System Settings → Privacy & Security → Accessibility, select Fixer, turn access on, return to the original app, and try the shortcut again.",
            dismissAfter: 5.5,
            outputMode: nil
        )
        let largeTextSize = HUDLayout.panelSize(for: largeTextPresentation.phase)
        try render(
            HUDStatusPanel(
                presentation: largeTextPresentation,
                revision: 0,
                reduceMotion: true
            )
            .environment(\.dynamicTypeSize, .accessibility3)
            .frame(width: largeTextSize.width, height: largeTextSize.height),
            size: largeTextSize,
            to: previewRoot.appendingPathComponent("feedback-error-large-text.png"),
            settleFor: 0.1,
            windowBackground: .clear,
            validate: { bitmap in
                try validateAdaptiveHUDCard(bitmap, panelSize: largeTextSize)
            }
        )
    }

    @MainActor
    private func render<V: View>(
        _ view: V,
        size: NSSize,
        to destination: URL,
        settleFor delay: TimeInterval,
        windowBackground: NSColor = Fixer.baseNS,
        validate: ((NSBitmapImageRep) throws -> Void)? = nil
    ) throws {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = windowBackground
        window.isOpaque = windowBackground.alphaComponent >= 0.999
        window.hasShadow = false
        window.contentView = hosting
        window.orderBack(nil)
        defer { window.orderOut(nil) }

        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(delay))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw PreviewRenderError.bitmapCreationFailed
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try validate?(bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw PreviewRenderError.pngEncodingFailed
        }
        try data.write(to: destination, options: .atomic)

        // GitHub credentials in this environment intentionally lack workflow
        // scope, so CI cannot add an artifact-upload step. Emit a bounded PNG
        // payload in the test log; the review task decodes it for visual QA.
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("FIXER_PREVIEW_BASE64_BEGIN \(destination.lastPathComponent)")
            print(data.base64EncodedString())
            print("FIXER_PREVIEW_BASE64_END \(destination.lastPathComponent)")
        }
    }

    /// A written PNG is not sufficient evidence: the old async preview produced a
    /// valid paper-only image. These broad color/alpha checks require the complete
    /// identity while tolerating antialiasing and small rendering differences.
    private func validateSettledSplash(
        _ bitmap: NSBitmapImageRep,
        stageSize: NSSize
    ) throws {
        let pixelWidth = bitmap.pixelsWide
        let pixelHeight = bitmap.pixelsHigh
        guard pixelWidth > 0, pixelHeight > 0 else {
            throw PreviewRenderError.invalidSplashRender("empty bitmap")
        }

        let cornerInset = 2
        let corners = [
            (cornerInset, cornerInset),
            (pixelWidth - cornerInset - 1, cornerInset),
            (cornerInset, pixelHeight - cornerInset - 1),
            (pixelWidth - cornerInset - 1, pixelHeight - cornerInset - 1)
        ]
        for (x, y) in corners {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  color.alphaComponent < 0.05 else {
                throw PreviewRenderError.invalidSplashRender("transparent stage corner became opaque")
            }
        }

        let cardSize = SplashMotionMetrics.cardSize(in: stageSize)
        let pointOrigin = CGPoint(
            x: (stageSize.width - cardSize.width) / 2,
            y: (stageSize.height - cardSize.height) / 2
        )
        let scaleX = CGFloat(pixelWidth) / stageSize.width
        let scaleY = CGFloat(pixelHeight) / stageSize.height
        let pixelFrame = CGRect(
            x: pointOrigin.x * scaleX,
            y: pointOrigin.y * scaleY,
            width: cardSize.width * scaleX,
            height: cardSize.height * scaleY
        ).insetBy(dx: 8 * scaleX, dy: 8 * scaleY)

        var samples = 0
        var opaqueSamples = 0
        var darkSamples = 0
        var yellowSamples = 0
        var minimumLuminance: CGFloat = 1
        var maximumLuminance: CGFloat = 0

        for y in stride(from: Int(pixelFrame.minY), to: Int(pixelFrame.maxY), by: 10) {
            for x in stride(from: Int(pixelFrame.minX), to: Int(pixelFrame.maxX), by: 10) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                samples += 1
                guard color.alphaComponent > 0.9 else { continue }
                opaqueSamples += 1

                let red = color.redComponent
                let green = color.greenComponent
                let blue = color.blueComponent
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                minimumLuminance = min(minimumLuminance, luminance)
                maximumLuminance = max(maximumLuminance, luminance)

                if red < 0.34, green < 0.34, blue < 0.34 {
                    darkSamples += 1
                }
                if red > 0.66, green > 0.45, blue < 0.34, red > blue * 2 {
                    yellowSamples += 1
                }
            }
        }

        guard samples > 0,
              opaqueSamples > Int(Double(samples) * 0.86),
              darkSamples > Int(Double(samples) * 0.01),
              yellowSamples > Int(Double(samples) * 0.01),
              maximumLuminance - minimumLuminance > 0.45 else {
            throw PreviewRenderError.invalidSplashRender(
                "identity layers are incomplete (opaque \(opaqueSamples)/\(samples), dark \(darkSamples), yellow \(yellowSamples))"
            )
        }
    }

    /// The run UI must be a compact neutral status surface, not a branded prop
    /// or an opaque black banner. Transparent corners prove the AppKit stage
    /// remains invisible; broad color checks verify surface, ink, semantic
    /// status, and the absence of the old yellow repair decoration.
    private func validateHUDCard(
        _ bitmap: NSBitmapImageRep,
        panelSize: NSSize,
        cardSize: NSSize,
        phase: RunFeedbackPresentation.Phase
    ) throws {
        let pixelWidth = bitmap.pixelsWide
        let pixelHeight = bitmap.pixelsHigh
        guard pixelWidth > 0, pixelHeight > 0 else {
            throw PreviewRenderError.invalidHUDRender("empty bitmap")
        }

        try validateTransparentHUDStageEdges(bitmap)

        let scaleX = CGFloat(pixelWidth) / panelSize.width
        let scaleY = CGFloat(pixelHeight) / panelSize.height
        let cardOrigin = HUDLayout.cardOrigin(for: phase)
        let pointFrame = CGRect(
            x: cardOrigin.x,
            y: cardOrigin.y,
            width: cardSize.width,
            height: cardSize.height
        ).insetBy(dx: 7, dy: 7)
        let pixelFrame = CGRect(
            x: pointFrame.minX * scaleX,
            y: pointFrame.minY * scaleY,
            width: pointFrame.width * scaleX,
            height: pointFrame.height * scaleY
        )

        var samples = 0
        var opaqueSamples = 0
        var neutralSurfaceSamples = 0
        var inkSamples = 0
        var yellowSamples = 0
        var successSamples = 0
        var errorSamples = 0

        for y in stride(from: Int(pixelFrame.minY), to: Int(pixelFrame.maxY), by: 4) {
            for x in stride(from: Int(pixelFrame.minX), to: Int(pixelFrame.maxX), by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                samples += 1
                guard color.alphaComponent > 0.88 else { continue }
                opaqueSamples += 1

                let red = color.redComponent
                let green = color.greenComponent
                let blue = color.blueComponent
                if red > 0.78, green > 0.74, blue > 0.66,
                   abs(red - green) < 0.13,
                   abs(green - blue) < 0.15 {
                    neutralSurfaceSamples += 1
                }
                if red < 0.38, green < 0.36, blue < 0.32 {
                    inkSamples += 1
                }
                if red > 0.72,
                   green > 0.55,
                   blue < 0.62,
                   red > blue * 1.35,
                   green > blue * 1.2 {
                    yellowSamples += 1
                }
                if green > red * 1.25, green > blue * 1.18, green > 0.34 {
                    successSamples += 1
                }
                if red > green * 1.25, red > blue * 1.18, red > 0.42 {
                    errorSamples += 1
                }
            }
        }

        guard samples > 0,
              opaqueSamples > Int(Double(samples) * 0.86),
              neutralSurfaceSamples > Int(Double(samples) * 0.64),
              inkSamples > 3,
              yellowSamples < Int(Double(samples) * 0.01),
              phase != .success || successSamples > 0,
              phase != .error || errorSamples > 0 else {
            throw PreviewRenderError.invalidHUDRender(
                "status surface is incomplete (opaque \(opaqueSamples)/\(samples), neutral \(neutralSurfaceSamples), ink \(inkSamples), yellow \(yellowSamples), success \(successSamples), error \(errorSamples))"
            )
        }
    }

    /// The full perimeter must stay transparent. Checking only the four corners
    /// missed a shadow that reached the middle of every panel edge.
    private func validateTransparentHUDStageEdges(
        _ bitmap: NSBitmapImageRep
    ) throws {
        let pixelWidth = bitmap.pixelsWide
        let pixelHeight = bitmap.pixelsHigh
        guard pixelWidth > 1, pixelHeight > 1 else {
            throw PreviewRenderError.invalidHUDRender("empty bitmap")
        }

        var maximumEdgeAlpha: CGFloat = 0

        for x in 0..<pixelWidth {
            for y in [0, pixelHeight - 1] {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                maximumEdgeAlpha = max(maximumEdgeAlpha, color.alphaComponent)
            }
        }

        for y in 0..<pixelHeight {
            for x in [0, pixelWidth - 1] {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                maximumEdgeAlpha = max(maximumEdgeAlpha, color.alphaComponent)
            }
        }

        guard maximumEdgeAlpha < 0.025 else {
            throw PreviewRenderError.invalidHUDRender(
                "HUD shadow reached a panel edge (max alpha \(maximumEdgeAlpha))"
            )
        }
    }

    /// Multi-line copy must grow the neutral surface beyond the normal error
    /// minimum instead of clipping or truncating inside a fixed 86-point card.
    private func validateAdaptiveHUDCard(
        _ bitmap: NSBitmapImageRep,
        panelSize: NSSize
    ) throws {
        try validateTransparentHUDStageEdges(bitmap)

        let pixelWidth = bitmap.pixelsWide
        let pixelHeight = bitmap.pixelsHigh
        let scaleY = CGFloat(pixelHeight) / panelSize.height
        var surfaceRows: [Int] = []

        for y in 0..<pixelHeight {
            var opaquePixels = 0
            for x in 0..<pixelWidth {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.95 else {
                    continue
                }
                opaquePixels += 1
            }
            if opaquePixels > Int(Double(pixelWidth) * 0.70) {
                surfaceRows.append(y)
            }
        }

        guard let first = surfaceRows.first, let last = surfaceRows.last else {
            throw PreviewRenderError.invalidHUDRender("adaptive status surface is missing")
        }

        let renderedHeight = CGFloat(last - first + 1) / scaleY
        guard renderedHeight > HUDLayout.errorCardSize.height + 12 else {
            throw PreviewRenderError.invalidHUDRender(
                "long copy did not grow the status surface (height \(renderedHeight))"
            )
        }
    }
}

private struct WorkspaceRenderCase {
    let filename: String
    let size: NSSize
}

private enum PreviewRenderError: Error {
    case bitmapCreationFailed
    case pngEncodingFailed
    case invalidSplashRender(String)
    case invalidHUDRender(String)
}

@MainActor
private final class PreviewHotkeyBinding: HotkeyBinding {
    func unbind(name: KeyboardShortcuts.Name) {}
    func reconcile(actions: [MacroAction]) {}
}

private final class PreviewAPIKeyStore: APIKeyStoring {
    private var value: String?

    init(value: String?) {
        self.value = value
    }

    func saveAPIKey(_ key: String) throws {
        value = key
    }

    func getAPIKey() throws -> String? {
        value
    }

    func deleteAPIKey() throws {
        value = nil
    }
}
