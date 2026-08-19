import Testing
@testable import fixer

struct HUDErrorCopyTests {
    @Test func selectionFailureGivesTheNextPhysicalStep() {
        let copy = HUDErrorCopy(message: "No text selected.")

        #expect(copy.title == "No text selected")
        #expect(copy.detail == "Select text, then run the shortcut again.")
    }

    @Test func accessibilityFailurePointsToTheCorrectSystemArea() {
        let copy = HUDErrorCopy(
            message: "Enable Accessibility for fixer in System Settings → Privacy & Security."
        )

        #expect(copy.title == "Accessibility permission needed")
        #expect(copy.detail == "Enable it in System Settings → Privacy & Security.")
    }

    @Test func twoSentenceProviderMessageBecomesTitleAndNextStep() {
        let copy = HUDErrorCopy(
            message: "No Gemini API key set. Open Settings and paste your key."
        )

        #expect(copy.title == "API key needed")
        #expect(copy.detail == "Open Setup, add the Gemini API key, then try again.")
    }

    @Test func arbitraryTwoSentenceMessagePreservesItsUsefulInstruction() {
        let copy = HUDErrorCopy(message: "Request timed out. Try the action again.")

        #expect(copy.title == "Request timed out")
        #expect(copy.detail == "Try the action again.")
    }

    @Test func emptyMessageStillProducesCompleteCopy() {
        let copy = HUDErrorCopy(message: "   ")

        #expect(copy.title == "Couldn’t finish")
        #expect(copy.detail == "Open the menu for details, then try again.")
    }
}
