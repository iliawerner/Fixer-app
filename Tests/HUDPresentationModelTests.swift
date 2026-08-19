import Testing
@testable import fixer

@MainActor
struct HUDPresentationModelTests {
    @Test func announcesInitialAndEveryPresentedPhaseExactlyOnce() {
        let sink = RecordingHUDAnnouncementSink()
        let working = RunFeedbackPresentation.working(actionName: "Fix Grammar")
        let model = HUDPresentationModel(
            presentation: working,
            announcementSink: sink
        )

        #expect(sink.values == ["Processing text… Fix Grammar"])

        // Reading or displaying the initial value must not repeat its announcement.
        _ = model.presentation
        #expect(sink.values.count == 1)

        let success = RunFeedbackPresentation.success(
            actionName: "Fix Grammar",
            mode: .replace
        )
        model.present(success)
        #expect(sink.values == ["Processing text… Fix Grammar", "Text replaced"])

        model.beginDismissal()
        #expect(sink.values.count == 2)

        model.present(.busy(actionName: "Fix Grammar"))
        #expect(
            sink.values
                == [
                    "Processing text… Fix Grammar",
                    "Text replaced",
                    "Already running. Fix Grammar"
                ]
        )
    }

    @Test func preservesIdentityWhilePublishingSemanticPhaseChanges() {
        let working = RunFeedbackPresentation.working(actionName: "Fix Grammar")
        let model = HUDPresentationModel(presentation: working)

        #expect(model.presentation == working)
        #expect(model.revision == 0)
        #expect(model.isVisible)

        let success = RunFeedbackPresentation.success(
            actionName: "Fix Grammar",
            mode: .replace
        )
        model.present(success)

        #expect(model.presentation == success)
        #expect(model.presentation.outputMode == .replace)
        #expect(model.revision == 1)
        #expect(model.isVisible)
    }

    @Test func aNewPhaseCanReverseAnInFlightDismissal() {
        let model = HUDPresentationModel(
            presentation: .success(actionName: "Fix Grammar", mode: .replace)
        )

        model.beginDismissal()
        #expect(!model.isVisible)

        model.present(.working(actionName: "Draft Reply"))
        #expect(model.isVisible)
        #expect(model.revision == 1)
        #expect(model.presentation.phase == .working)
    }
}

@MainActor
private final class RecordingHUDAnnouncementSink: HUDAnnouncementSinking {
    private(set) var values: [String] = []

    func announce(_ text: String) {
        values.append(text)
    }
}
