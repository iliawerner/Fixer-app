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
    func rendersWorkspaceAndRunFeedback() throws {
        let previewRoot = URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["FIXER_PREVIEW_DIR"]
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
                [GeminiModel(name: "models/gemini-2.5-flash", displayName: "Gemini 2.5 Flash")]
            }
        )

        settings.actions = [
            MacroAction(
                name: "Fix grammar",
                shortcutName: KeyboardShortcuts.Name("preview-fix-grammar"),
                promptTemplate: "Fix grammar and make it sound simple and natural: {text}. Return only the corrected text.",
                modelName: "models/gemini-2.5-flash",
                outputMode: .replace
            ),
            MacroAction(
                name: "Make concise",
                shortcutName: KeyboardShortcuts.Name("preview-make-concise"),
                promptTemplate: "Make this shorter without losing meaning: {text}",
                modelName: "models/gemini-2.5-flash",
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

        try render(
            SettingsView(
                settings: settings,
                appState: appState,
                provider: provider,
                refreshAccessibilityOnAppear: false
            )
            .frame(width: 980, height: 700),
            size: NSSize(width: 980, height: 700),
            to: previewRoot.appendingPathComponent("workspace.png"),
            settleFor: 0.25
        )

        try render(
            SplashView(autoDismiss: false, onDismiss: {})
                .frame(width: 576, height: 456),
            size: NSSize(width: 576, height: 456),
            to: previewRoot.appendingPathComponent("splash-settled.png"),
            settleFor: 1.9
        )

        let feedback: [(String, RunFeedbackPresentation)] = [
            ("feedback-working.png", .working(actionName: "Fix grammar")),
            ("feedback-success.png", .success(actionName: "Fix grammar", mode: .replace)),
            ("feedback-error.png", .error("No text selected. Select text, then trigger the shortcut."))
        ]

        for (filename, presentation) in feedback {
            let size = presentation.phase == .error
                ? NSSize(width: 380, height: 132)
                : NSSize(width: 368, height: 88)
            try render(
                RepairHUDView(presentation: presentation),
                size: size,
                to: previewRoot.appendingPathComponent(filename),
                settleFor: 0.22
            )
        }
    }

    @MainActor
    private func render<V: View>(
        _ view: V,
        size: NSSize,
        to destination: URL,
        settleFor delay: TimeInterval
    ) throws {
        let hosting = NSHostingView(rootView: view)
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
        RunLoop.current.run(until: Date().addingTimeInterval(delay))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw PreviewRenderError.bitmapCreationFailed
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
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
}

private enum PreviewRenderError: Error {
    case bitmapCreationFailed
    case pngEncodingFailed
}

@MainActor
private final class PreviewHotkeyBinding: HotkeyBinding {
    func bind(name: KeyboardShortcuts.Name, actionID: UUID) {}
    func unbind(name: KeyboardShortcuts.Name) {}
    func setEnabled(_ enabled: Bool, name: KeyboardShortcuts.Name) {}
}

private final class PreviewAPIKeyStore: APIKeyStoring {
    private var value: String?

    init(value: String?) {
        self.value = value
    }

    func saveAPIKey(_ key: String) throws {
        value = key
    }

    func getAPIKey() -> String? {
        value
    }

    func deleteAPIKey() throws {
        value = nil
    }
}
