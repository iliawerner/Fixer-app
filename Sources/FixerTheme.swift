import SwiftUI
import AppKit
import CoreText

/// Signal-paper design tokens for Fixer v2. The palette is intentionally fixed
/// rather than following the system tint: warm paper keeps the utility calm,
/// near-black carries hierarchy, and signal yellow is reserved for state and
/// action. Legacy token names remain as aliases so saved behavior can evolve
/// independently from the visual rewrite.
enum Fixer {
    // Surfaces
    static let base     = Color(hex: 0xF2EAD8) // warm paper
    static let panel    = Color(hex: 0xF7F1E4) // raised working surface
    static let film     = Color(hex: 0xE9E0CE) // quiet secondary surface
    static let line     = Color(hex: 0xD8CEBB) // hairline rule
    static let line2    = Color(hex: 0xBFB4A0) // stronger rule / field border

    // Brand and semantic color
    static let yellow      = Color(hex: 0xF4BF00)
    static let yellowDark  = Color(hex: 0xC99500)
    static let yellowWash  = Color(hex: 0xFFF0A6)
    static let safelight   = yellow       // legacy alias
    static let amber       = yellowDark  // legacy alias
    static let kodak       = yellow      // legacy alias
    static let fixed       = Color(hex: 0x2F8A52)
    static let safeText    = Color(hex: 0xA4362D)
    static let warningWash = Color(hex: 0xF8DCD5)

    // Ink
    static let text    = Color(hex: 0x14130F)
    static let textDim = Color(hex: 0x454139)
    static let muted   = Color(hex: 0x655F55)
    static let muted2  = Color(hex: 0x9A9488)

    static let baseNS = NSColor(
        srgbRed: 0xF2 / 255.0,
        green: 0xEA / 255.0,
        blue: 0xD8 / 255.0,
        alpha: 1
    )

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
