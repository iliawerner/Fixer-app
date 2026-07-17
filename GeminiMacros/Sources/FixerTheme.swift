import SwiftUI
import AppKit
import CoreText

/// Design tokens for the "fixer" darkroom look: near-black warm surfaces, a red
/// safelight accent, amber, and Kodak-yellow edge markings. Light-on-dark, so
/// text tokens keep strong contrast on the base.
enum Fixer {
    // Darkroom surfaces
    static let base   = Color(hex: 0x0C0A09) // darkroom black (warm)
    static let panel  = Color(hex: 0x15110E) // lifted panel / inset field
    static let film   = Color(hex: 0x1E1613) // film-frame surface
    static let line   = Color(hex: 0x2C231E) // hairline border
    static let line2  = Color(hex: 0x3E322B) // brighter hairline

    // Accents
    static let safelight = Color(hex: 0xE8402E) // safelight red — dots, borders, active
    static let safeText  = Color(hex: 0xF2705F) // brighter red for small text on dark
    static let amber     = Color(hex: 0xE39A3C) // amber
    static let kodak     = Color(hex: 0xF2C21A) // Kodak yellow — edge labels
    static let fixed     = Color(hex: 0x5FBE86) // "fixed / ok" (used sparingly)

    // Text
    static let text    = Color(hex: 0xEBE3D6) // warm off-white
    static let textDim = Color(hex: 0xC3B7A7)
    static let muted   = Color(hex: 0x938676) // warm grey
    static let muted2  = Color(hex: 0x6A5E51)

    static let baseNS = NSColor(srgbRed: 0x0C/255.0, green: 0x0A/255.0, blue: 0x09/255.0, alpha: 1)

    // MARK: Fonts
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.custom("Archivo Narrow", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }

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
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: 1)
    }
}
