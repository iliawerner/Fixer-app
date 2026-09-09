import SwiftUI
import AppKit
import CoreText

/// Signal-paper and warm-charcoal palettes. Named dynamic AppKit colors resolve
/// against each view's effective appearance, including native controls and open
/// windows when the app preference or macOS appearance changes.
enum Fixer {
    // Surfaces
    static let baseNS = adaptiveNS("base", light: 0xF2EAD8, dark: 0x191A17)
    static let base = Color(nsColor: baseNS)
    static let panel = adaptive("panel", light: 0xF7F1E4, dark: 0x22231F)
    static let film = adaptive("film", light: 0xE9E0CE, dark: 0x2C2D27)
    static let input = adaptive("input", light: 0xF7F1E4, dark: 0x1C1D19)
    static let line = adaptive("line", light: 0xD8CEBB, dark: 0x30322B)
    static let line2 = adaptive("line2", light: 0xBFB4A0, dark: 0x3C3E35)
    static let separator = adaptive("separator", light: 0xD8CEBB, dark: 0x2B2D26)
    static let chromeLine = adaptive("chromeLine", light: 0xBFB4A0, dark: 0x2B2D26)

    // Brand and semantic color
    static let yellow = adaptive("yellow", light: 0xF4BF00, dark: 0xE6BC43)
    static let yellowDark = adaptive("yellowDark", light: 0xC99500, dark: 0xC3A044)
    static let yellowWash = adaptive("yellowWash", light: 0xFFF0A6, dark: 0x3D3724)
    static let fixed = adaptive("fixed", light: 0x2F8A52, dark: 0x88BC92)
    static let safeText = adaptive("safeText", light: 0xA4362D, dark: 0xEEA299)
    static let warningWash = adaptive("warningWash", light: 0xF8DCD5, dark: 0x452C28)

    // Ink
    static let text = adaptive("text", light: 0x14130F, dark: 0xEEEBDD)
    static let textDim = adaptive("textDim", light: 0x454139, dark: 0xC8C6B8)
    static let muted = adaptive("muted", light: 0x655F55, dark: 0xACAD9F)
    static let muted2 = adaptive("muted2", light: 0x9A9488, dark: 0x838678)
    static let onAccent = adaptive("onAccent", light: 0x14130F, dark: 0x191A17)

    // Role-specific colors keep dark ink on yellow separate from body text.
    static let masthead = adaptive("masthead", light: 0xF4BF00, dark: 0x302D20)
    static let mastheadText = adaptive("mastheadText", light: 0x14130F, dark: 0xE6BC43)
    static let gridInk = adaptive(
        "gridInk", light: 0x14130F, dark: 0xE6BC43, lightAlpha: 0.035, darkAlpha: 0.026
    )
    static let selection = adaptive("selection", light: 0x14130F, dark: 0x3D3724)
    static let selectionBorder = adaptive("selectionBorder", light: 0x14130F, dark: 0x4A4330)
    static let selectedText = adaptive("selectedText", light: 0xF2EAD8, dark: 0xE6BC43)
    static let selectedWarning = adaptive("selectedWarning", light: 0xF8DCD5, dark: 0xEEA299)
    static let selectedSecondary = adaptive(
        "selectedSecondary", light: 0xF2EAD8, dark: 0xC8C6B8, lightAlpha: 0.74
    )
    static let selectedControlBorder = adaptive(
        "selectedControlBorder", light: 0xC99500, dark: 0x4A4330
    )
    static let selectedKeycap = adaptive(
        "selectedKeycap", light: 0x14130F, dark: 0x191A17, lightAlpha: 0.92
    )
    static let selectedKeycapBorder = adaptive(
        "selectedKeycapBorder", light: 0xF2EAD8, dark: 0x4A4330, lightAlpha: 0.2
    )

    private static func adaptive(
        _ name: String, light: UInt32, dark: UInt32,
        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
    ) -> Color {
        Color(nsColor: adaptiveNS(name, light: light, dark: dark,
                                 lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }

    private static func adaptiveNS(
        _ name: String, light: UInt32, dark: UInt32,
        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: NSColor.Name("Fixer.\(name)")) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        }
    }

    // MARK: Fonts

    /// Large product and action names use the native macOS face. It has better
    /// metrics and accessibility behavior than carrying a web prototype font
    /// into a desktop utility.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    // Kept for continuity with old builds that bundled Archivo Narrow. V2 does
    // not depend on it, but registering it is harmless for existing resources.
    private static var fontsRegistered = false
    static func registerFonts() {
        guard !fontsRegistered else { return }
        fontsRegistered = true
        for name in ["ArchivoNarrow"] {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            if let url {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
