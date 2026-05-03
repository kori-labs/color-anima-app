import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspacePendingCloseCoordinatorTests: XCTestCase {
    func testNoPendingRequestDoesNothing() {
        let prompt = MockPendingClosePrompting()
        let recorder = PendingCloseRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: nil,
            projectName: "Project",
            existingRootURL: nil,
            saveChanges: true
        )

        XCTAssertTrue(prompt.directoryRequests.isEmpty)
        XCTAssertTrue(recorder.resolutions.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testSaveUsesExistingRootURLWithoutPrompting() {
        let prompt = MockPendingClosePrompting()
        let recorder = PendingCloseRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)
        let rootURL = URL(fileURLWithPath: "/tmp/existing-project")

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Project",
            existingRootURL: rootURL,
            saveChanges: true
        )

        XCTAssertTrue(prompt.directoryRequests.isEmpty)
        XCTAssertEqual(recorder.resolutions, [
            PendingCloseRecorder.Resolution(saveChanges: true, url: rootURL),
        ])
    }

    func testSavePromptsWithSanitizedProjectNameWhenRootURLIsMissing() {
        let prompt = MockPendingClosePrompting()
        let saveURL = URL(fileURLWithPath: "/tmp/save-project")
        prompt.directoryResponses = [saveURL]
        let recorder = PendingCloseRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Scene/Shot",
            existingRootURL: nil,
            saveChanges: true
        )

        XCTAssertEqual(prompt.directoryRequests, [
            MockPendingClosePrompting.DirectoryRequest(title: "Save Project", suggestedName: "Scene-Shot"),
        ])
        XCTAssertEqual(recorder.resolutions, [
            PendingCloseRecorder.Resolution(saveChanges: true, url: saveURL),
        ])
    }

    func testSaveCancellationLeavesRequestUnresolved() {
        let prompt = MockPendingClosePrompting()
        prompt.directoryResponses = [nil]
        let recorder = PendingCloseRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Project",
            existingRootURL: nil,
            saveChanges: true
        )

        XCTAssertEqual(prompt.directoryRequests.count, 1)
        XCTAssertTrue(recorder.resolutions.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testDiscardResolvesWithoutURL() {
        let prompt = MockPendingClosePrompting()
        let recorder = PendingCloseRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Project",
            existingRootURL: nil,
            saveChanges: false
        )

        XCTAssertTrue(prompt.directoryRequests.isEmpty)
        XCTAssertEqual(recorder.resolutions, [
            PendingCloseRecorder.Resolution(saveChanges: false, url: nil),
        ])
    }

    func testResolutionErrorIsReported() {
        let prompt = MockPendingClosePrompting()
        let recorder = PendingCloseRecorder()
        recorder.resolutionError = PendingCloseError.failed
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Project",
            existingRootURL: nil,
            saveChanges: false
        )

        XCTAssertEqual(recorder.errors, [PendingCloseError.failed.localizedDescription])
    }

    private func makeCoordinator(
        prompting: MockPendingClosePrompting,
        recorder: PendingCloseRecorder
    ) -> WorkspacePendingCloseCoordinator {
        let saveResolver = WorkspaceProjectSaveResolver(prompting: prompting)
        return WorkspacePendingCloseCoordinator(
            saveResolver: saveResolver,
            resolveClose: { saveChanges, url in
                if let resolutionError = recorder.resolutionError {
                    throw resolutionError
                }
                recorder.resolutions.append(PendingCloseRecorder.Resolution(saveChanges: saveChanges, url: url))
            },
            reportError: { message in
                recorder.errors.append(message)
            }
        )
    }
}

@MainActor
private final class PendingCloseRecorder {
    struct Resolution: Equatable {
        var saveChanges: Bool
        var url: URL?
    }

    var resolutions: [Resolution] = []
    var errors: [String] = []
    var resolutionError: Error?
}

@MainActor
private final class MockPendingClosePrompting: WorkspaceProjectInteractionPrompting {
    struct DirectoryRequest: Equatable {
        var title: String
        var suggestedName: String
    }

    var directoryRequests: [DirectoryRequest] = []
    var directoryResponses: [URL?] = []

    func chooseProjectDirectory(title: String, suggestedName: String) throws -> URL? {
        directoryRequests.append(DirectoryRequest(title: title, suggestedName: suggestedName))
        return directoryResponses.isEmpty ? nil : directoryResponses.removeFirst()
    }

    func openProjectDirectory(title: String) throws -> URL? {
        fatalError("Not used in pending close tests")
    }

    func confirmUnsavedChanges(dirtyCutCount: Int) throws -> WorkspaceProjectInteractionChoice {
        fatalError("Not used in pending close tests")
    }
}

private enum PendingCloseError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Pending close failed"
    }
}
