import Foundation
import Testing
@testable import fixer

struct ActionDetailMotionTests {
    @Test
    func replacementUsesABriefExitBeforeTheLongerEntrance() {
        #expect(FixerMotion.replacementExitDuration > 0)
        #expect(FixerMotion.replacementEntranceDuration > FixerMotion.replacementExitDuration)
        #expect(FixerMotion.replacementExitDuration <= 0.15)
        #expect(FixerMotion.replacementEntranceDuration <= 0.28)
        #expect(
            FixerMotion.replacementExitDuration + FixerMotion.replacementEntranceDuration
                <= 0.40
        )
        #expect(
            FixerMotion.replacementSwapDelay(reduceMotion: false)
                == FixerMotion.replacementExitDuration
        )
    }

    @Test
    func sharedMotionKeepsControlsAndFocusImmediate() {
        #expect(FixerMotion.workspaceDuration <= 0.40)
        #expect(FixerMotion.controlDuration <= 0.22)
        #expect(FixerMotion.focusDuration <= 0.20)
    }

    @Test
    func reduceMotionCollapsesTheSpatialReplacementDelay() {
        #expect(FixerMotion.replacementSwapDelay(reduceMotion: true) <= 0.05)
    }

    @Test
    func rapidRetargetSwapsOnlyTheLatestRequestedAction() {
        let first = UUID()
        let second = UUID()
        let latest = UUID()
        var state = ActionReplacementState(actionID: first)

        state.request(second)
        state.request(latest)

        #expect(state.displayedActionID == first)
        #expect(state.requestedActionID == latest)
        #expect(state.phase == .exiting)

        state.swapToLatestRequest()
        #expect(state.displayedActionID == latest)
        #expect(state.phase == .entering)

        state.settle()
        #expect(state.phase == .settled)
    }

    @Test
    func returningToDisplayedActionCancelsThePendingReplacement() {
        let first = UUID()
        var state = ActionReplacementState(actionID: first)

        state.request(UUID())
        #expect(state.phase == .exiting)

        state.request(first)
        #expect(state.displayedActionID == first)
        #expect(state.requestedActionID == first)
        #expect(state.phase == .settled)
    }

    @Test
    func identitySwapOccursAtAnInvisibleBoundary() {
        #expect(ReplacementPhase.exiting.opacity == 0)
        #expect(ReplacementPhase.entering.opacity == 0)
        #expect(ReplacementPhase.settled.opacity == 1)
        #expect(abs(ReplacementPhase.entering.horizontalOffset) <= 8)
        #expect(abs(ReplacementPhase.exiting.horizontalOffset) <= 8)
    }

    @Test
    func deletionRetainsOutgoingIdentityUntilTheInvisibleBoundary() {
        let deleted = UUID()
        let survivor = UUID()
        var state = ActionReplacementState(actionID: deleted)

        state.beginExit()
        #expect(state.displayedActionID == deleted)
        #expect(state.phase == .exiting)
        #expect(state.phase.opacity == 0)

        state.swapImmediately(to: survivor)
        #expect(state.displayedActionID == survivor)
        #expect(state.requestedActionID == survivor)
        #expect(state.phase == .entering)
        #expect(state.phase.opacity == 0)
    }

    @Test
    func deletionKeepsTheUsersLatestSurvivingRetarget() {
        let deleted = UUID()
        let fallback = UUID()
        let requested = UUID()
        var state = ActionReplacementState(actionID: deleted)

        state.beginExit()
        state.request(requested)

        #expect(
            state.deletionSuccessor(
                deleting: deleted,
                availableActionIDs: [deleted, fallback, requested]
            ) == requested
        )
    }
}
