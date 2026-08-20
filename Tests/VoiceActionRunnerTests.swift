import Testing
@testable import fixer

struct VoiceActionRunnerTests {
    @Test func voiceOnlyAppendCapturesSelectionSoItCanPreserveIt() {
        let append = MacroAction(
            name: "Voice note",
            shortcutName: .init("voiceAppendSelectionTest"),
            promptTemplate: "Rewrite this instruction: {voice}",
            modelName: defaultModelName,
            outputMode: .append
        )
        let replace = MacroAction(
            name: "Voice replacement",
            shortcutName: .init("voiceReplaceSelectionTest"),
            promptTemplate: "Rewrite this instruction: {voice}",
            modelName: defaultModelName,
            outputMode: .replace
        )

        #expect(
            VoiceSelectionCapturePolicy.requiresSelection(
                for: append,
                selectionLength: 8
            )
        )
        #expect(
            !VoiceSelectionCapturePolicy.requiresSelection(
                for: append,
                selectionLength: 0
            )
        )
        #expect(
            VoiceSelectionCapturePolicy.requiresSelection(
                for: append,
                selectionLength: nil
            )
        )
        #expect(
            !VoiceSelectionCapturePolicy.requiresSelection(
                for: replace,
                selectionLength: 8
            )
        )

        var textTokenAtCaret = replace
        textTokenAtCaret.promptTemplate = "Rewrite {text} using {voice}"
        #expect(
            VoiceSelectionCapturePolicy.requiresSelection(
                for: textTokenAtCaret,
                selectionLength: 0
            )
        )
        #expect(
            ActionRunner.composeOutput(
                mode: append.outputMode,
                selectionText: "Original",
                response: "Result"
            ) == "Original\nResult"
        )
    }

    @Test func substitutesEveryOriginalVoiceAndTextOccurrence() {
        let prompt = VoiceActionRunner.buildVoicePrompt(
            template: "Instruction: {voice}. Source: {text}. Again: {voice}",
            selectionText: "Selected",
            transcript: "Make it warmer"
        )

        #expect(prompt == "Instruction: Make it warmer. Source: Selected. Again: Make it warmer")
    }

    @Test func tokensInsideUserContentRemainLiteral() {
        let prompt = VoiceActionRunner.buildVoicePrompt(
            template: "{voice} :: {text}",
            selectionText: "selection says {voice}",
            transcript: "say {text} literally"
        )

        #expect(prompt == "say {text} literally :: selection says {voice}")
    }

    @Test func missingSelectionFailsOnlyWhenTemplateRequestsIt() {
        #expect(
            VoiceActionRunner.buildVoicePrompt(
                template: "Rewrite {text} using {voice}",
                selectionText: "",
                transcript: "Shorter"
            ) == nil
        )
        #expect(
            VoiceActionRunner.buildVoicePrompt(
                template: "Turn this into a note: {voice}",
                selectionText: "ignored selection",
                transcript: "Buy milk"
            ) == "Turn this into a note: Buy milk"
        )
    }

    @Test func emptyTranscriptNeverCreatesAProviderRequestPrompt() {
        #expect(
            VoiceActionRunner.buildVoicePrompt(
                template: "Use {voice}",
                selectionText: "",
                transcript: ""
            ) == nil
        )
    }
}
