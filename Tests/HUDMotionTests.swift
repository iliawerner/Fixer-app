import Testing
@testable import fixer

struct HUDMotionTests {
    @Test func acknowledgementAndStatusChangesStayResponsive() {
        #expect(HUDMotion.acknowledgementDuration == 0.12)
        #expect(HUDMotion.entranceDuration == 0.12)
        #expect(HUDMotion.phaseDuration == 0.14)
        #expect(HUDMotion.dismissalDuration <= 0.20)
    }

    @Test func onlyInProgressStatesUseAnIndeterminateIndicator() {
        #expect(HUDMotion.shouldAnimateProgress(phase: .working, reduceMotion: false))
        #expect(HUDMotion.shouldAnimateProgress(phase: .busy, reduceMotion: false))
        #expect(!HUDMotion.shouldAnimateProgress(phase: .success, reduceMotion: false))
        #expect(!HUDMotion.shouldAnimateProgress(phase: .error, reduceMotion: false))
    }

    @Test func reduceMotionRemovesContinuousAndSpatialMotion() {
        #expect(!HUDMotion.shouldAnimateProgress(phase: .working, reduceMotion: true))
        #expect(!HUDMotion.shouldAnimateProgress(phase: .busy, reduceMotion: true))
        #expect(HUDMotion.panelOffset(isPresented: false, reduceMotion: true) == 0)
        #expect(HUDMotion.panelOffset(isPresented: true, reduceMotion: true) == 0)
    }

    @Test func standardMotionUsesOnlyAShortEntranceOffset() {
        #expect(HUDMotion.panelOffset(isPresented: false, reduceMotion: false) == 4)
        #expect(HUDMotion.panelOffset(isPresented: true, reduceMotion: false) == 0)
    }
}
