import CoreGraphics

/// Geometry for the deliberately asymmetric workspace chrome.
///
/// The navigation rail stays on AppKit's compact titlebar axis, while the
/// selected Action receives a taller document-like masthead. Keeping both
/// heights explicit makes that contrast intentional rather than font-driven.
enum WorkspaceChromeMetrics {
    /// Matches AppKit's `.unifiedCompact` titlebar exactly. The traffic lights
    /// and the sidebar tools therefore share one native center line.
    static let headerHeight: CGFloat = 40
    /// Gives the selected Action enough identity without returning to the old,
    /// oversized decorative banner.
    static let editorMastheadHeight: CGFloat = 100
    /// The compact titlebar's zoom button ends at x = 72 pt on macOS 26.
    /// Sixteen further points keep the add control related but never crowded.
    static let trafficLightClearance: CGFloat = 88
    static let titlebarControlSize: CGFloat = 28
    static let mastheadTitleControlHeight: CGFloat = 42
    static let sidebarWidth: CGFloat = 292
}
