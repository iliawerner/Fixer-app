import Foundation
import Testing
@testable import fixer

@MainActor
struct TextHistoryLifecycleTests {
    @Test func sourceIsDurableBeforeRequestAndOutputBeforeDelivery() async throws {
        let fixture = TextHistoryFixture()
        defer { fixture.removeFiles() }
        var action = fixture.action
        action.outputMode = .append
        let runner = fixture.runner(generate: { model, prompt in
            let entry = try fixture.diskEntry()
            #expect(entry.sourceText == "original")
            #expect(entry.prompt == prompt)
            #expect(entry.action.modelName == model)
            #expect(entry.stage == .generation)
            #expect(entry.status == .running)
            return "updated"
        })
        let task = try #require(runner.run(action: action))
        // The saved Action must retain the invocation snapshot.
        action.promptTemplate = "edited during request"
        #expect(runner.run(action: action) == nil)
        await task.value
        let entry = try fixture.diskEntry()
        #expect(entry.status == .succeeded)
        #expect(entry.action.promptTemplate == "Fix {text}")
        #expect(entry.result == "original\nupdated")
        #expect(entry.delivery == .historyOnly)
        #expect(!fixture.state.isProcessing)
    }

    @Test func unavailableSelectionNeverCallsProviderOrDelivery() async throws {
        let fixture = TextHistoryFixture()
        defer { fixture.removeFiles() }
        let runner = fixture.runner(selection: nil, generate: { _, _ in
            Issue.record("Unverified source must not be uploaded"); return "unexpected"
        })
        await runner.run(action: fixture.action)?.value
        #expect(try fixture.diskEntry().status == .failed)
        #expect(fixture.deliveries.isEmpty)
        #expect(!fixture.state.isProcessing)
    }

    @Test func providerFailureKeepsSourceAndPartialFailureNeverDelivers() async throws {
        let fixture = TextHistoryFixture()
        defer { fixture.removeFiles() }
        let runner = fixture.runner(generate: { _, _ in
            throw GeminiAPI.APIError.incompleteResponse("partial")
        })
        await runner.run(action: fixture.action)?.value
        let entry = try fixture.diskEntry()
        #expect(entry.sourceText == "original")
        #expect(entry.result == "partial")
        #expect(entry.status == .failed)
        #expect(entry.stage == .generation)
        #expect(entry.errorMessage?.contains("incomplete") == true)
        #expect(fixture.deliveries.isEmpty)
    }

    @Test func persistenceFailurePreventsRequest() async throws {
        let fixture = TextHistoryFixture()
        defer { fixture.removeFiles() }
        // A file occupying the history root makes the very first write fail.
        try Data("occupied".utf8).write(to: fixture.directory)
        let runner = fixture.runner(generate: { _, _ in
            Issue.record("Provider must not run without durable input"); return "unexpected"
        })
        await runner.run(action: fixture.action)?.value
        #expect(fixture.history.entries.first?.status == .failed)
        #expect(fixture.history.entries.first?.sourceText == "original")
        #expect(fixture.history.persistenceError != nil)
        #expect(fixture.deliveries.isEmpty)
    }

    @Test func resultSaveFailurePreservesOutputInMemoryAndNeverDelivers() async throws {
        let fixture = TextHistoryFixture()
        defer { fixture.removeFiles() }
        let runner = fixture.runner(generate: { _, _ in
            let entry = try #require(fixture.history.entries.first)
            // An unreadable destination simulates a storage failure after the
            // request, when the original source has already been saved.
            let path = fixture.directory.appendingPathComponent(entry.id.uuidString)
                .appendingPathComponent("entry.json")
            try FileManager.default.removeItem(at: path)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
            return "complete response"
        })
        await runner.run(action: fixture.action)?.value
        #expect(fixture.history.entries.first?.result == "complete response")
        #expect(fixture.history.entries.first?.sourceText == "original")
        #expect(fixture.history.entries.first?.status == .failed)
        #expect(fixture.history.persistenceError != nil)
        #expect(fixture.deliveries.isEmpty)
    }
}

@MainActor
private final class TextHistoryFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("text-history-\(UUID())")
    lazy var history = HistoryStore(directory: directory)
    let state = AppState()
    let action = MacroAction(name: "Test", shortcutName: .init("textHistoryTest"), promptTemplate: "Fix {text}")
    var deliveries: [String] = []
    func runner(selection: String? = "original",
                generate: @escaping (String, String) async throws -> String) -> ActionRunner {
        ActionRunner(history: history, state: state,
            captureTarget: { .init(processIdentifier: 99, sourceAppName: "Editor", selectedTextRange: .init(location: 0, length: 8)) },
            readSelection: { _ in selection }, hasAccessibility: { true }, generate: generate,
            deliver: { [self] result, target in
                #expect(target?.sourceAppName == "Editor")
                #expect((try? diskEntry().result) == result)
                #expect((try? diskEntry().stage) == .delivery)
                deliveries.append(result)
                return .historyOnly
            }, feedback: { _ in })
    }
    func diskEntry() throws -> HistoryEntry {
        let id = try #require(history.entries.first?.id)
        let path = directory.appendingPathComponent(id.uuidString).appendingPathComponent("entry.json")
        return try JSONDecoder().decode(HistoryEntry.self, from: Data(contentsOf: path))
    }
    func removeFiles() { try? FileManager.default.removeItem(at: directory) }
}
