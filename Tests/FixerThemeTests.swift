import AppKit
import SwiftUI
import Testing
@testable import fixer

struct FixerThemeTests {
    @Test @MainActor
    func semanticForegroundsStayReadableInBothAppearances() throws {
        let pairs: [(Color, Color)] = [
            (Fixer.text, Fixer.panel),
            (Fixer.text, Fixer.input),
            (Fixer.muted, Fixer.panel),
            (Fixer.selectedText, Fixer.selection),
            (Fixer.selectedSecondary, Fixer.selection),
            (Fixer.selectedWarning, Fixer.selection),
            (Fixer.mastheadText, Fixer.masthead),
            (Fixer.onAccent, Fixer.yellow),
            (Fixer.safeText, Fixer.warningWash)
        ]
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try #require(NSAppearance(named: name))
            for (foreground, background) in pairs {
                let ratio = try contrast(foreground, background, appearance: appearance)
                #expect(ratio >= 4.5, "Text contrast is \(ratio):1 in \(name.rawValue)")
            }
        }
    }

    @Test @MainActor
    func darkDividersRemainQuietWhileFocusStaysVisible() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        for surface in [Fixer.base, Fixer.panel] {
            #expect(try contrast(Fixer.separator, surface, appearance: dark) < 1.4)
        }
        #expect(try contrast(Fixer.selectionBorder, Fixer.selection, appearance: dark) < 1.4)
        #expect(try contrast(Fixer.yellowDark, Fixer.input, appearance: dark) >= 3)
    }

    @MainActor
    private func contrast(_ foreground: Color, _ background: Color, appearance: NSAppearance) throws -> Double {
        let back = try resolved(background, appearance: appearance)
        let front = try resolved(foreground, appearance: appearance)
        let alpha = Double(front.alphaComponent)
        let bg = [back.redComponent, back.greenComponent, back.blueComponent].map(Double.init)
        let fg = [front.redComponent, front.greenComponent, front.blueComponent].map(Double.init)
        let blended = zip(fg, bg).map { $0 * alpha + $1 * (1 - alpha) }
        let values = [luminance(blended), luminance(bg)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    @MainActor
    private func resolved(_ color: Color, appearance: NSAppearance) throws -> NSColor {
        var result: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            result = NSColor(color).usingColorSpace(.sRGB)
        }
        return try #require(result)
    }

    private func luminance(_ components: [Double]) -> Double {
        let linear = components.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
