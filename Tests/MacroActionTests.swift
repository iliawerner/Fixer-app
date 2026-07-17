import Testing
import Foundation
import KeyboardShortcuts
@testable import fixer

/// The most important guarantee: one corrupt element in the persisted array must
/// not throw the whole decode (which would reseed defaults and wipe every macro).
struct MacroActionTests {

    @Test func corruptOutputModeDoesNotWipeArray() throws {
        let json = """
        [
          {"id":"11111111-1111-1111-1111-111111111111","name":"Good","shortcutName":"s1","promptTemplate":"Fix: {text}","modelName":"models/gemini-2.5-flash","outputMode":"Replace","isEnabled":true},
          {"id":"22222222-2222-2222-2222-222222222222","name":"Bad mode","shortcutName":"s2","promptTemplate":"X","modelName":"m","outputMode":"Banana","isEnabled":true}
        ]
        """.data(using: .utf8)!

        let actions = try JSONDecoder().decode([MacroAction].self, from: json)

        #expect(actions.count == 2)              // NOT wiped
        #expect(actions[0].name == "Good")
        #expect(actions[1].name == "Bad mode")
        #expect(actions[1].outputMode == .replace) // invalid rawValue fell back to default
    }

    @Test func malformedUUIDFallsBackInsteadOfThrowing() throws {
        let json = """
        [{"id":"not-a-uuid","name":"X","shortcutName":"s","promptTemplate":"P","modelName":"m","outputMode":"Append","isEnabled":false}]
        """.data(using: .utf8)!

        let actions = try JSONDecoder().decode([MacroAction].self, from: json)

        #expect(actions.count == 1)
        #expect(actions[0].outputMode == .append)
        #expect(actions[0].isEnabled == false)
        // A fresh UUID was substituted for the malformed one rather than throwing.
    }

    @Test func missingKeysFallBackToDefaults() throws {
        let actions = try JSONDecoder().decode([MacroAction].self, from: "[{}]".data(using: .utf8)!)

        #expect(actions.count == 1)
        let a = actions[0]
        #expect(a.name == "New action")
        #expect(a.promptTemplate == "Fix grammar and phrasing: {text}")
        #expect(a.modelName == defaultModelName)
        #expect(a.outputMode == .replace)
        #expect(a.isEnabled == true)
    }

    @Test func encodeDecodeRoundTrip() throws {
        let original = MacroAction(name: "Round",
                                   shortcutName: KeyboardShortcuts.Name("myKey"),
                                   promptTemplate: "T {text}",
                                   modelName: "models/x",
                                   outputMode: .append,
                                   isEnabled: false)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MacroAction.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == "Round")
        #expect(decoded.shortcutName.rawValue == "myKey")   // Name round-trips via rawValue
        #expect(decoded.promptTemplate == "T {text}")
        #expect(decoded.modelName == "models/x")
        #expect(decoded.outputMode == .append)
        #expect(decoded.isEnabled == false)
    }
}
