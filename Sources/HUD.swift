import SwiftUI

/// SwiftUI content of the passive run-feedback panel.
///
/// The surrounding `HUDPresentationModel` stays alive while phases change, so
/// the panel can update its status without blinking or taking keyboard focus.
struct RunFeedbackHUDView: View {
    @ObservedObject private var model: HUDPresentationModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    @MainActor
    init(model: HUDPresentationModel) {
        self.model = model
    }

    /// Convenience initializer for deterministic previews and render tests.
    @MainActor
    init(presentation: RunFeedbackPresentation) {
        model = HUDPresentationModel(presentation: presentation)
    }

    private var isPresented: Bool {
        hasAppeared && model.isVisible
    }

    var body: some View {
        ZStack {
            HUDStatusPanel(
                presentation: model.presentation,
                revision: model.revision,
                reduceMotion: reduceMotion,
                activityLevel: model.activityLevel
            )
            .offset(
                y: HUDMotion.panelOffset(
                    isPresented: isPresented,
                    reduceMotion: reduceMotion
                )
            )
            .animation(HUDMotion.entrance(reduceMotion: reduceMotion), value: isPresented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .opacity(isPresented ? 1 : 0)
        .animation(HUDMotion.acknowledgement(reduceMotion: reduceMotion), value: isPresented)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.presentation.label)
        .accessibilityValue(accessibilityValue)
        .onAppear {
            hasAppeared = true
        }
    }

    private var accessibilityValue: String {
        guard !model.presentation.detail.isEmpty else {
            return model.presentation.title
        }
        return "\(model.presentation.title). \(model.presentation.detail)"
    }
}
