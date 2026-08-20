import AppKit

/// Geometry contract for the compact Actions workspace.
///
/// The window is large enough for the master-detail workflow, but no longer
/// inherits the oversized frame saved by the earlier admin-panel layout. Window
/// chrome is intentionally absent from this contract: AppKit owns the titlebar,
/// traffic lights, shadow, resize affordance, and current system corner radius.
enum WorkspaceWindowMetrics {
    /// Matches the natural width of the 292 pt sidebar, divider, editor insets,
    /// and 480 pt settings column instead of adding an empty trailing strip.
    static let defaultSize = NSSize(width: 820, height: 720)
    static let minimumSize = NSSize(width: 760, height: 620)

    /// Changing the autosave namespace is intentional. The previous V3 window
    /// could restore a much wider frame and defeat the new compact launch size;
    /// V4 starts once from this geometry, then resumes normal AppKit restoration.
    static let autosaveName = "FixerV4NarrowWorkspace"
}
