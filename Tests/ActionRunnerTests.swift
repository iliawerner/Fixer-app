import Testing
@testable import fixer

struct ActionRunnerTests {

    // MARK: buildPrompt

    @Test func substitutesEveryTextOccurrence() {
        #expect(ActionRunner.buildPrompt(template: "{text} and {text}", selectionText: "X") == "X and X")
    }

    @Test func literalPlaceholderInSelectionIsNotReSubstituted() {
        // replacingOccurrences is single-pass: a `{text}` that appears in the
        // selection must be left as-is, not treated as another slot.
        #expect(ActionRunner.buildPrompt(template: "Fix: {text}", selectionText: "a {text} b") == "Fix: a {text} b")
    }

    @Test func noPlaceholderAppendsSelection() {
        #expect(ActionRunner.buildPrompt(template: "Summarize", selectionText: "hello") == "Summarize\n\nhello")
    }

    @Test func noPlaceholderEmptySelectionSendsTemplateAlone() {
        #expect(ActionRunner.buildPrompt(template: "Say hi", selectionText: "") == "Say hi")
    }

    @Test func placeholderWithEmptySelectionAborts() {
        #expect(ActionRunner.buildPrompt(template: "Fix: {text}", selectionText: "") == nil)
    }

    // MARK: composeOutput

    @Test func appendJoinsSelectionAndResponse() {
        #expect(ActionRunner.composeOutput(mode: .append, selectionText: "orig", response: "resp") == "orig\nresp")
    }

    @Test func appendWithEmptySelectionIsResponseOnly() {
        #expect(ActionRunner.composeOutput(mode: .append, selectionText: "", response: "resp") == "resp")
    }

    @Test func replaceIsAlwaysResponseOnly() {
        #expect(ActionRunner.composeOutput(mode: .replace, selectionText: "orig", response: "resp") == "resp")
    }
}
