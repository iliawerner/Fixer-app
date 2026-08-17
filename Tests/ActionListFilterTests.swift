import Testing
import KeyboardShortcuts
@testable import fixer

struct ActionListFilterTests {
    private func action(
        name: String = "Fix Grammar",
        prompt: String = "Correct the selected text",
        model: String = "models/gemini-2.5-flash"
    ) -> MacroAction {
        MacroAction(
            name: name,
            shortcutName: KeyboardShortcuts.Name("test-\(name)"),
            promptTemplate: prompt,
            modelName: model
        )
    }

    @Test func emptyQueryIncludesEveryAction() {
        #expect(ActionListFilter.matches(action(), query: ""))
        #expect(ActionListFilter.matches(action(), query: "   "))
    }

    @Test func queryMatchesActionNameCaseInsensitively() {
        #expect(ActionListFilter.matches(action(name: "Translate to English"), query: "translate"))
        #expect(ActionListFilter.matches(action(name: "Translate to English"), query: "ENGLISH"))
    }

    @Test func queryMatchesPromptAndModelMetadata() {
        let item = action(prompt: "Return only three concise bullets", model: "models/gemini-2.5-pro")
        #expect(ActionListFilter.matches(item, query: "bullets"))
        #expect(ActionListFilter.matches(item, query: "2.5-pro"))
    }

    @Test func unrelatedQueryExcludesAction() {
        #expect(!ActionListFilter.matches(action(), query: "translate"))
    }
}
