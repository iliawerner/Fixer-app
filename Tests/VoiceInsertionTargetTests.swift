import CoreFoundation
import Testing
@testable import fixer

struct VoiceInsertionTargetTests {
    @Test func exactProcessAndElementRemainSafeForAutomaticPaste() {
        #expect(
            VoiceInsertionTargetPolicy.isCurrent(
                originalPID: 42,
                currentPID: 42,
                originalHadElement: true,
                elementsMatch: true
            )
        )
    }

    @Test func switchingAppsOrFieldsFailsClosed() {
        #expect(
            !VoiceInsertionTargetPolicy.isCurrent(
                originalPID: 42,
                currentPID: 43,
                originalHadElement: true,
                elementsMatch: true
            )
        )
        #expect(
            !VoiceInsertionTargetPolicy.isCurrent(
                originalPID: 42,
                currentPID: 42,
                originalHadElement: true,
                elementsMatch: false
            )
        )
    }

    @Test func movingTheCaretInsideTheSameFieldFailsClosed() {
        #expect(
            !VoiceInsertionTargetPolicy.isCurrent(
                originalPID: 42,
                currentPID: 42,
                originalHadElement: true,
                elementsMatch: true,
                rangesMatch: false
            )
        )
        #expect(
            VoiceInsertionTargetPolicy.rangesMatch(
                CFRange(location: 12, length: 0),
                CFRange(location: 12, length: 0)
            )
        )
        #expect(
            !VoiceInsertionTargetPolicy.rangesMatch(
                CFRange(location: 12, length: 0),
                CFRange(location: 18, length: 0)
            )
        )
    }

    @Test func missingAccessibilityElementIsNeverTreatedAsVerified() {
        #expect(
            !VoiceInsertionTargetPolicy.isCurrent(
                originalPID: 42,
                currentPID: 42,
                originalHadElement: false,
                elementsMatch: false
            )
        )
    }
}
