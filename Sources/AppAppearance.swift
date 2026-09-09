import AppKit

/// A stored user choice. System deliberately has no AppKit override so macOS
/// continues to update existing windows when its appearance changes.
enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Follow System"
        }
    }

    var appKitAppearance: NSAppearance? {
        switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}
