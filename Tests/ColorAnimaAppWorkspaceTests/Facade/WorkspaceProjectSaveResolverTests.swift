import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspaceProjectSaveResolverTests: XCTestCase {
    func testExistingRootURLIsReusedWithoutPrompting() throws {
        let prompting = MockWorkspaceProjectSavePrompting()
        let resolver = WorkspaceProjectSaveResolver(prompting: prompting)
        let existingURL = URL(fileURLWithPath: "/tmp/existing-project")

        let resolved = try resolver.resolveSaveTargetURL(
            existingRootURL: existingURL,
            title: "Save Project",
            suggestedName: "Project"
        )

        XCTAssertEqual(resolved, existingURL)
        XCTAssertTrue(prompting.directoryRequests.isEmpty)
    }

    func testMissingRootURLPromptsForDirectory() throws {
        let prompting = MockWorkspaceProjectSavePrompting()
        let chosenURL = URL(fileURLWithPath: "/tmp/chosen-project")
        prompting.directoryResponses = [chosenURL]
        let resolver = WorkspaceProjectSaveResolver(prompting: prompting)

        let resolved = try resolver.resolveSaveTargetURL(
            existingRootURL: nil,
            title: "Save Project",
            suggestedName: "Shot A"
        )

        XCTAssertEqual(resolved, chosenURL)
        XCTAssertEqual(
            prompting.directoryRequests,
            [MockWorkspaceProjectSavePrompting.DirectoryRequest(title: "Save Project", suggestedName: "Shot A")]
        )
    }

    func testPromptCancellationReturnsNil() throws {
        let prompting = MockWorkspaceProjectSavePrompting()
        prompting.directoryResponses = [nil]
        let resolver = WorkspaceProjectSaveResolver(prompting: prompting)

        let resolved = try resolver.resolveSaveTargetURL(
            existingRootURL: nil,
            title: "Save Project",
            suggestedName: "Project"
        )

        XCTAssertNil(resolved)
        XCTAssertEqual(prompting.directoryRequests.count, 1)
    }
}

@MainActor
private final class MockWorkspaceProjectSavePrompting: WorkspaceProjectInteractionPrompting {
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
        fatalError("Not used in save resolver tests")
    }

    func confirmUnsavedChanges(dirtyCutCount: Int) throws -> WorkspaceProjectInteractionChoice {
        fatalError("Not used in save resolver tests")
    }
}
