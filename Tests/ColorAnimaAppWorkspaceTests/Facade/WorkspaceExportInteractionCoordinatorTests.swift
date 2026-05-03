import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspaceExportInteractionCoordinatorTests: XCTestCase {
    func testExportVisiblePreviewPromptsAndDispatchesPreviewExport() throws {
        let prompt = MockWorkspaceExportInteractionPrompting()
        let outputURL = URL(fileURLWithPath: "/tmp/visible-preview.png")
        prompt.savePNGResponses = [outputURL]
        let recorder = ExportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.exportVisiblePreview()

        XCTAssertEqual(prompt.events, [.savePNG(definition: .visiblePreview)])
        XCTAssertEqual(recorder.previewExports, [
            ExportRecorder.PreviewExport(definition: .visiblePreview, url: outputURL),
        ])
        XCTAssertTrue(recorder.sequenceExports.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testExportReviewPreviewCancellationDoesNotDispatch() throws {
        let prompt = MockWorkspaceExportInteractionPrompting()
        prompt.savePNGResponses = [nil]
        let recorder = ExportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.exportReviewPreview()

        XCTAssertEqual(prompt.events, [.savePNG(definition: .reviewPreview)])
        XCTAssertTrue(recorder.previewExports.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testExportSequencePromptsAndDispatchesDirectoryExport() {
        let prompt = MockWorkspaceExportInteractionPrompting()
        let outputURL = URL(fileURLWithPath: "/tmp/png-sequence", isDirectory: true)
        prompt.saveDirectoryResponses = [outputURL]
        let recorder = ExportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.exportSequence()

        XCTAssertEqual(prompt.events, [.saveDirectory(title: "Export PNG Sequence")])
        XCTAssertEqual(recorder.sequenceExports, [outputURL])
        XCTAssertTrue(recorder.previewExports.isEmpty)
    }

    func testExportSequenceCancellationDoesNotDispatch() {
        let prompt = MockWorkspaceExportInteractionPrompting()
        prompt.saveDirectoryResponses = [nil]
        let recorder = ExportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.exportSequence()

        XCTAssertEqual(prompt.events, [.saveDirectory(title: "Export PNG Sequence")])
        XCTAssertTrue(recorder.sequenceExports.isEmpty)
    }

    func testPreviewPromptErrorIsReported() {
        let prompt = MockWorkspaceExportInteractionPrompting()
        prompt.savePNGError = MockExportPromptError.denied
        let recorder = ExportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.exportVisiblePreview()

        XCTAssertEqual(prompt.events, [.savePNG(definition: .visiblePreview)])
        XCTAssertTrue(recorder.previewExports.isEmpty)
        XCTAssertEqual(recorder.errors, [MockExportPromptError.denied.localizedDescription])
    }

    private func makeCoordinator(
        prompting: MockWorkspaceExportInteractionPrompting,
        recorder: ExportRecorder
    ) -> WorkspaceExportInteractionCoordinator {
        WorkspaceExportInteractionCoordinator(
            prompting: prompting,
            exportPreview: { definition, url in
                recorder.previewExports.append(ExportRecorder.PreviewExport(definition: definition, url: url))
            },
            exportPNGSequence: { url in
                recorder.sequenceExports.append(url)
            },
            reportError: { message in
                recorder.errors.append(message)
            }
        )
    }
}

@MainActor
private final class ExportRecorder {
    struct PreviewExport: Equatable {
        var definition: WorkspaceExportDefinition
        var url: URL
    }

    var previewExports: [PreviewExport] = []
    var sequenceExports: [URL] = []
    var errors: [String] = []
}

@MainActor
private final class MockWorkspaceExportInteractionPrompting: WorkspaceExportInteractionPrompting {
    enum Event: Equatable {
        case savePNG(definition: WorkspaceExportDefinition)
        case saveDirectory(title: String)
    }

    var events: [Event] = []
    var savePNGResponses: [URL?] = []
    var saveDirectoryResponses: [URL?] = []
    var savePNGError: Error?

    func savePNG(for definition: WorkspaceExportDefinition) throws -> URL? {
        events.append(.savePNG(definition: definition))
        if let savePNGError {
            throw savePNGError
        }
        return savePNGResponses.isEmpty ? nil : savePNGResponses.removeFirst()
    }

    func saveDirectory(title: String) -> URL? {
        events.append(.saveDirectory(title: title))
        return saveDirectoryResponses.isEmpty ? nil : saveDirectoryResponses.removeFirst()
    }
}

private enum MockExportPromptError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Export prompt denied"
    }
}
