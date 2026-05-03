import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspaceTreeInteractionCoordinatorTests: XCTestCase {
    func testRenameSelectedNodePromptsAndRenamesNode() {
        let node = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .cut,
            name: "CUT001"
        )
        let prompt = MockWorkspaceTreeInteractionPrompting()
        prompt.responses = ["Renamed Cut"]
        let recorder = TreeInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.renameSelectedNode(node)

        XCTAssertEqual(prompt.events, [
            .promptForName(
                title: "Rename Cut",
                message: "Enter a new name for the selected cut.",
                defaultValue: "CUT001"
            ),
        ])
        XCTAssertEqual(recorder.renameRequests, [
            TreeInteractionRecorder.RenameRequest(id: node.id, name: "Renamed Cut"),
        ])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testRenameSelectedNodeCancellationLeavesNodeUntouched() {
        let node = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .sequence,
            name: "SQ001"
        )
        let prompt = MockWorkspaceTreeInteractionPrompting()
        prompt.responses = [nil]
        let recorder = TreeInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.renameSelectedNode(node)

        XCTAssertEqual(prompt.events.count, 1)
        XCTAssertTrue(recorder.renameRequests.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testRenameSelectedNodeWithoutSelectionDoesNothing() {
        let prompt = MockWorkspaceTreeInteractionPrompting()
        prompt.responses = ["Unused"]
        let recorder = TreeInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.renameSelectedNode(nil)

        XCTAssertTrue(prompt.events.isEmpty)
        XCTAssertTrue(recorder.renameRequests.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testPromptErrorIsReported() {
        let node = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .scene,
            name: "SC001"
        )
        let prompt = MockWorkspaceTreeInteractionPrompting()
        prompt.error = TreeInteractionError.failed
        let recorder = TreeInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.renameSelectedNode(node)

        XCTAssertTrue(recorder.renameRequests.isEmpty)
        XCTAssertEqual(recorder.errors, [TreeInteractionError.failed.localizedDescription])
    }

    func testRenameErrorIsReported() {
        let node = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .project,
            name: "Project"
        )
        let prompt = MockWorkspaceTreeInteractionPrompting()
        prompt.responses = ["Renamed Project"]
        let recorder = TreeInteractionRecorder()
        recorder.renameError = TreeInteractionError.failed
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.renameSelectedNode(node)

        XCTAssertEqual(recorder.renameRequests, [
            TreeInteractionRecorder.RenameRequest(id: node.id, name: "Renamed Project"),
        ])
        XCTAssertEqual(recorder.errors, [TreeInteractionError.failed.localizedDescription])
    }

    private func makeCoordinator(
        prompting: MockWorkspaceTreeInteractionPrompting,
        recorder: TreeInteractionRecorder
    ) -> WorkspaceTreeInteractionCoordinator {
        WorkspaceTreeInteractionCoordinator(
            prompting: prompting,
            renameNode: { id, name in
                recorder.renameRequests.append(TreeInteractionRecorder.RenameRequest(id: id, name: name))
                if let renameError = recorder.renameError {
                    throw renameError
                }
            },
            reportError: { message in
                recorder.errors.append(message)
            }
        )
    }
}

@MainActor
private final class TreeInteractionRecorder {
    struct RenameRequest: Equatable {
        var id: UUID
        var name: String
    }

    var renameRequests: [RenameRequest] = []
    var errors: [String] = []
    var renameError: Error?
}

@MainActor
private final class MockWorkspaceTreeInteractionPrompting: WorkspaceTreeInteractionPrompting {
    enum Event: Equatable {
        case promptForName(title: String, message: String, defaultValue: String)
    }

    var events: [Event] = []
    var responses: [String?] = []
    var error: Error?

    func promptForName(title: String, message: String, defaultValue: String) throws -> String? {
        if let error {
            throw error
        }
        events.append(.promptForName(title: title, message: message, defaultValue: defaultValue))
        return responses.isEmpty ? nil : responses.removeFirst()
    }
}

private enum TreeInteractionError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Tree interaction failed"
    }
}
