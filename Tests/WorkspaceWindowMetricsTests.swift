import Testing
@testable import fixer

struct WorkspaceWindowMetricsTests {
    @Test
    func defaultWorkspaceIsCompactButUseful() {
        let naturalWidth = WorkspaceChromeMetrics.sidebarWidth
            + 1
            + ActionEditorMetrics.contentMaximumWidth
            + (ActionEditorMetrics.contentInset * 2)
        let minimumEditorWidth = WorkspaceWindowMetrics.minimumSize.width
            - WorkspaceChromeMetrics.sidebarWidth
            - 1
            - (ActionEditorMetrics.contentInset * 2)

        #expect(WorkspaceWindowMetrics.defaultSize == .init(width: 820, height: 720))
        #expect(WorkspaceWindowMetrics.minimumSize == .init(width: 760, height: 620))
        #expect(ActionEditorMetrics.contentMaximumWidth == 480)
        #expect(abs(WorkspaceWindowMetrics.defaultSize.width - naturalWidth) <= 4)
        #expect(minimumEditorWidth >= 420)
        #expect(minimumEditorWidth <= 424)
        #expect(WorkspaceWindowMetrics.minimumSize.width < WorkspaceWindowMetrics.defaultSize.width)
        #expect(WorkspaceWindowMetrics.minimumSize.height < WorkspaceWindowMetrics.defaultSize.height)
    }

    @Test
    func compactGeometryGetsANewRestorationNamespace() {
        #expect(WorkspaceWindowMetrics.autosaveName == "FixerV4NarrowWorkspace")
    }

    @Test
    func workspaceMotionKeepsTheViscousCurveInAResponsiveRange() {
        #expect(FixerMotion.workspaceDuration >= 0.28)
        #expect(FixerMotion.workspaceDuration <= 0.40)
        #expect(FixerMotion.controlDuration >= 0.14)
        #expect(FixerMotion.controlDuration <= 0.22)
        #expect(FixerMotion.focusDuration >= 0.12)
        #expect(FixerMotion.focusDuration <= 0.20)
        #expect(FixerMotion.hoverDuration >= 0.08)
        #expect(FixerMotion.hoverDuration <= 0.13)
        #expect(FixerMotion.pressDuration >= 0.06)
        #expect(FixerMotion.pressDuration <= 0.10)
    }
}
