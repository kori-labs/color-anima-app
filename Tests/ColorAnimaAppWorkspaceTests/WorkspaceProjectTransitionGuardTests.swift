import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspaceProjectTransitionGuardTests: XCTestCase {
    func testConfirmTransitionWithoutUnsavedChangesDoesNotPrompt() throws {
        let prompting = MockWorkspaceProjectTransitionPrompting()
        let transitionGuard = WorkspaceProjectTransitionGuard(prompting: prompting)

        let decision = try transitionGuard.confirmTransitionIfNeeded(dirtyCutCount: 3, hasUnsavedChanges: false)

        XCTAssertEqual(decision, .proceed)
        XCTAssertEqual(prompting.confirmations, [])
    }

    func testConfirmTransitionMapsSaveChoiceToSaveDecision() throws {
        let prompting = MockWorkspaceProjectTransitionPrompting()
        prompting.responses = [.save]
        let transitionGuard = WorkspaceProjectTransitionGuard(prompting: prompting)

        let decision = try transitionGuard.confirmTransitionIfNeeded(dirtyCutCount: 2, hasUnsavedChanges: true)

        XCTAssertEqual(decision, .save)
        XCTAssertEqual(prompting.confirmations, [2])
    }

    func testConfirmTransitionMapsDiscardChoiceToProceedDecision() throws {
        let prompting = MockWorkspaceProjectTransitionPrompting()
        prompting.responses = [.discard]
        let transitionGuard = WorkspaceProjectTransitionGuard(prompting: prompting)

        let decision = try transitionGuard.confirmTransitionIfNeeded(dirtyCutCount: 1, hasUnsavedChanges: true)

        XCTAssertEqual(decision, .proceed)
        XCTAssertEqual(prompting.confirmations, [1])
    }

    func testConfirmTransitionMapsCancelChoiceToCancelDecision() throws {
        let prompting = MockWorkspaceProjectTransitionPrompting()
        prompting.responses = [.cancel]
        let transitionGuard = WorkspaceProjectTransitionGuard(prompting: prompting)

        let decision = try transitionGuard.confirmTransitionIfNeeded(dirtyCutCount: 4, hasUnsavedChanges: true)

        XCTAssertEqual(decision, .cancel)
        XCTAssertEqual(prompting.confirmations, [4])
    }
}

@MainActor
private final class MockWorkspaceProjectTransitionPrompting: WorkspaceProjectInteractionPrompting {
    var confirmations: [Int] = []
    var responses: [WorkspaceProjectInteractionChoice] = []

    func chooseProjectDirectory(title: String, suggestedName: String) throws -> URL? {
        fatalError("Not used in transition guard tests")
    }

    func openProjectDirectory(title: String) throws -> URL? {
        fatalError("Not used in transition guard tests")
    }

    func confirmUnsavedChanges(dirtyCutCount: Int) throws -> WorkspaceProjectInteractionChoice {
        confirmations.append(dirtyCutCount)
        return responses.isEmpty ? .cancel : responses.removeFirst()
    }
}
