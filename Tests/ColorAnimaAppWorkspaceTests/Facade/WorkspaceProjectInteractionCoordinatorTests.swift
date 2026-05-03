import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspaceProjectInteractionCoordinatorTests: XCTestCase {
    func testSaveProjectPromptsForTargetWhenProjectHasNoRootURL() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let saveURL = URL(fileURLWithPath: "/tmp/save-project")
        prompt.chooseProjectDirectoryResponses = [saveURL]
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.saveProject(
            projectName: "Untitled Project",
            existingRootURL: nil
        )

        XCTAssertEqual(prompt.events, [
            .chooseProjectDirectory(title: "Save Project", suggestedName: "Untitled Project"),
        ])
        XCTAssertEqual(recorder.saveRequests, [saveURL])
        XCTAssertEqual(recorder.clearErrorCount, 1)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testSaveProjectUsesExistingRootURLWithoutPrompting() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let saveURL = URL(fileURLWithPath: "/tmp/existing-project")
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.saveProject(
            projectName: "Existing Project",
            existingRootURL: saveURL
        )

        XCTAssertTrue(prompt.events.isEmpty)
        XCTAssertEqual(recorder.saveRequests, [saveURL])
        XCTAssertEqual(recorder.clearErrorCount, 1)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testOpenProjectSavesDirtySourceBeforeOpeningTarget() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let sourceURL = URL(fileURLWithPath: "/tmp/source-project")
        let targetURL = URL(fileURLWithPath: "/tmp/target-project")
        prompt.unsavedConfirmationResponses = [.save]
        prompt.openProjectDirectoryResponses = [targetURL]
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.openProject(
            projectName: "Source Project",
            existingRootURL: sourceURL,
            dirtyCutCount: 1,
            hasUnsavedChanges: true
        )

        XCTAssertEqual(prompt.events, [
            .confirmUnsavedChanges(dirtyCutCount: 1),
            .openProjectDirectory(title: "Open Project Folder"),
        ])
        XCTAssertEqual(recorder.saveRequests, [sourceURL])
        XCTAssertEqual(recorder.openRequests, [targetURL])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testNewProjectDiscardsDirtyChangesWhenPrompted() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let targetURL = URL(fileURLWithPath: "/tmp/new-project")
        prompt.unsavedConfirmationResponses = [.discard]
        prompt.chooseProjectDirectoryResponses = [targetURL]
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.newProject(
            projectName: "Scene/Shot",
            existingRootURL: URL(fileURLWithPath: "/tmp/source-project"),
            dirtyCutCount: 2,
            hasUnsavedChanges: true
        )

        XCTAssertEqual(prompt.events, [
            .confirmUnsavedChanges(dirtyCutCount: 2),
            .chooseProjectDirectory(title: "Create Project", suggestedName: "Scene-Shot"),
        ])
        XCTAssertTrue(recorder.saveRequests.isEmpty)
        XCTAssertEqual(recorder.createRequests, [targetURL])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testNewProjectCancellationLeavesCurrentProjectUntouched() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        prompt.unsavedConfirmationResponses = [.cancel]
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.newProject(
            projectName: "Project",
            existingRootURL: URL(fileURLWithPath: "/tmp/source-project"),
            dirtyCutCount: 1,
            hasUnsavedChanges: true
        )

        XCTAssertEqual(prompt.events, [.confirmUnsavedChanges(dirtyCutCount: 1)])
        XCTAssertTrue(recorder.createRequests.isEmpty)
        XCTAssertTrue(recorder.saveRequests.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testTransitionSaveCancellationStopsOpenProject() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        prompt.unsavedConfirmationResponses = [.save]
        prompt.chooseProjectDirectoryResponses = [nil]
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.openProject(
            projectName: "Unsaved Project",
            existingRootURL: nil,
            dirtyCutCount: 1,
            hasUnsavedChanges: true
        )

        XCTAssertEqual(prompt.events, [
            .confirmUnsavedChanges(dirtyCutCount: 1),
            .chooseProjectDirectory(title: "Save Project", suggestedName: "Unsaved Project"),
        ])
        XCTAssertTrue(recorder.openRequests.isEmpty)
        XCTAssertTrue(recorder.saveRequests.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testResolvePendingCloseDiscardDispatchesCloseResolution() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Project",
            existingRootURL: URL(fileURLWithPath: "/tmp/project"),
            saveChanges: false
        )

        XCTAssertTrue(prompt.events.isEmpty)
        XCTAssertEqual(recorder.closeResolutions, [
            ProjectInteractionRecorder.CloseResolution(saveChanges: false, url: nil),
        ])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testResolvePendingCloseSaveUsesExistingRootURL() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let saveURL = URL(fileURLWithPath: "/tmp/project")
        let recorder = ProjectInteractionRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.resolvePendingClose(
            request: WorkspacePendingCloseRequest(dirtyCutIDs: [UUID()]),
            projectName: "Project",
            existingRootURL: saveURL,
            saveChanges: true
        )

        XCTAssertTrue(prompt.events.isEmpty)
        XCTAssertEqual(recorder.closeResolutions, [
            ProjectInteractionRecorder.CloseResolution(saveChanges: true, url: saveURL),
        ])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testCallbackErrorIsReported() {
        let prompt = MockWorkspaceProjectInteractionCoordinatorPrompting()
        let saveURL = URL(fileURLWithPath: "/tmp/project")
        let recorder = ProjectInteractionRecorder()
        recorder.saveError = ProjectInteractionError.failed
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.saveProject(
            projectName: "Project",
            existingRootURL: saveURL
        )

        XCTAssertEqual(recorder.saveRequests, [saveURL])
        XCTAssertEqual(recorder.errors, [ProjectInteractionError.failed.localizedDescription])
        XCTAssertEqual(recorder.clearErrorCount, 0)
    }

    private func makeCoordinator(
        prompting: MockWorkspaceProjectInteractionCoordinatorPrompting,
        recorder: ProjectInteractionRecorder
    ) -> WorkspaceProjectInteractionCoordinator {
        WorkspaceProjectInteractionCoordinator(
            prompting: prompting,
            createProject: { url in
                recorder.createRequests.append(url)
            },
            openProject: { url in
                recorder.openRequests.append(url)
            },
            saveProject: { url in
                recorder.saveRequests.append(url)
                if let saveError = recorder.saveError {
                    throw saveError
                }
                return url
            },
            resolveClose: { saveChanges, url in
                recorder.closeResolutions.append(
                    ProjectInteractionRecorder.CloseResolution(saveChanges: saveChanges, url: url)
                )
            },
            clearError: {
                recorder.clearErrorCount += 1
            },
            reportError: { message in
                recorder.errors.append(message)
            }
        )
    }
}

@MainActor
private final class ProjectInteractionRecorder {
    struct CloseResolution: Equatable {
        var saveChanges: Bool
        var url: URL?
    }

    var createRequests: [URL] = []
    var openRequests: [URL] = []
    var saveRequests: [URL] = []
    var closeResolutions: [CloseResolution] = []
    var errors: [String] = []
    var clearErrorCount = 0
    var saveError: Error?
}

@MainActor
private final class MockWorkspaceProjectInteractionCoordinatorPrompting: WorkspaceProjectInteractionPrompting {
    enum Event: Equatable {
        case chooseProjectDirectory(title: String, suggestedName: String)
        case openProjectDirectory(title: String)
        case confirmUnsavedChanges(dirtyCutCount: Int)
    }

    var events: [Event] = []
    var chooseProjectDirectoryResponses: [URL?] = []
    var openProjectDirectoryResponses: [URL?] = []
    var unsavedConfirmationResponses: [WorkspaceProjectInteractionChoice] = []

    func chooseProjectDirectory(title: String, suggestedName: String) throws -> URL? {
        events.append(.chooseProjectDirectory(title: title, suggestedName: suggestedName))
        return chooseProjectDirectoryResponses.isEmpty ? nil : chooseProjectDirectoryResponses.removeFirst()
    }

    func openProjectDirectory(title: String) throws -> URL? {
        events.append(.openProjectDirectory(title: title))
        return openProjectDirectoryResponses.isEmpty ? nil : openProjectDirectoryResponses.removeFirst()
    }

    func confirmUnsavedChanges(dirtyCutCount: Int) throws -> WorkspaceProjectInteractionChoice {
        events.append(.confirmUnsavedChanges(dirtyCutCount: dirtyCutCount))
        return unsavedConfirmationResponses.isEmpty ? .cancel : unsavedConfirmationResponses.removeFirst()
    }
}

private enum ProjectInteractionError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Project interaction failed"
    }
}
