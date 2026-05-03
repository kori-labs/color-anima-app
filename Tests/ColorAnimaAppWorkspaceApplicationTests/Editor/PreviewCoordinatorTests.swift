import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest

// MARK: - Stub client

private struct StubPreviewRenderClient: PreviewRenderClientProtocol {
    let kernelExecuted: Bool
    let computedFrameCount: Int

    func run(
        frames: [PreviewCoordinatorFrameInput],
        canvasWidth: Int,
        canvasHeight: Int,
        selectedFrameID: UUID?
    ) -> PreviewCoordinatorRenderReport {
        PreviewCoordinatorRenderReport(
            computedFrameCount: kernelExecuted ? computedFrameCount : 0,
            kernelExecuted: kernelExecuted
        )
    }
}

// MARK: - Tests

final class PreviewCoordinatorTests: XCTestCase {

    // MARK: - Rebuild: unavailable stub path

    func testRebuildReturnsUnavailableEffectWhenKernelNotExposed() {
        let client = StubPreviewRenderClient(kernelExecuted: false, computedFrameCount: 0)
        let frames = makeFrames(count: 3)
        let canvas = PreviewCanvasDescriptor(width: 1920, height: 1080)

        let effect = PreviewCoordinator.rebuild(
            frames: frames,
            canvas: canvas,
            selectedFrameID: frames.first?.frameID,
            client: client
        )

        XCTAssertFalse(effect.kernelExecuted)
        XCTAssertEqual(effect.computedFrameCount, 0)
        XCTAssertTrue(effect.linePreviewImagesDirty, "linePreviewImagesDirty should be true when kernel unavailable")
    }

    // MARK: - Rebuild: executed path

    func testRebuildReturnsComputedCountWhenKernelExecuted() {
        let client = StubPreviewRenderClient(kernelExecuted: true, computedFrameCount: 3)
        let frames = makeFrames(count: 3)
        let canvas = PreviewCanvasDescriptor(width: 1920, height: 1080)

        let effect = PreviewCoordinator.rebuild(
            frames: frames,
            canvas: canvas,
            selectedFrameID: nil,
            client: client
        )

        XCTAssertTrue(effect.kernelExecuted)
        XCTAssertEqual(effect.computedFrameCount, 3)
        XCTAssertFalse(effect.linePreviewImagesDirty)
    }

    // MARK: - Rebuild: empty frames

    func testRebuildWithEmptyFramesReturnsZeroEffect() {
        let client = StubPreviewRenderClient(kernelExecuted: false, computedFrameCount: 0)
        let effect = PreviewCoordinator.rebuild(
            frames: [],
            canvas: PreviewCanvasDescriptor(width: 1920, height: 1080),
            selectedFrameID: nil,
            client: client
        )
        XCTAssertEqual(effect.computedFrameCount, 0)
        XCTAssertFalse(effect.kernelExecuted)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableEffect() {
        let effect = PreviewRebuildEffect(
            computedFrameCount: 0,
            kernelExecuted: false,
            linePreviewImagesDirty: true
        )
        let message = PreviewCoordinator.feedbackMessage(for: effect)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(
            message.contains("not yet available") || message.contains("kernel"),
            "Expected kernel unavailability message, got: \(message)"
        )
    }

    func testFeedbackMessageForExecutedEffect() {
        let effect = PreviewRebuildEffect(
            computedFrameCount: 5,
            kernelExecuted: true,
            linePreviewImagesDirty: false
        )
        let message = PreviewCoordinator.feedbackMessage(for: effect)
        XCTAssertTrue(message.contains("5"), "Expected frame count in message, got: \(message)")
    }

    // MARK: - DTO equality

    func testPreviewFrameDescriptorEquality() {
        let id = UUID()
        let a = PreviewFrameDescriptor(frameID: id, orderIndex: 0, hasComputedOverlay: true)
        let b = PreviewFrameDescriptor(frameID: id, orderIndex: 0, hasComputedOverlay: true)
        XCTAssertEqual(a, b)
    }

    func testPreviewCanvasDescriptorEquality() {
        let a = PreviewCanvasDescriptor(width: 1920, height: 1080)
        let b = PreviewCanvasDescriptor(width: 1920, height: 1080)
        XCTAssertEqual(a, b)
    }

    func testPreviewRebuildEffectEquality() {
        let a = PreviewRebuildEffect(computedFrameCount: 2, kernelExecuted: false, linePreviewImagesDirty: true)
        let b = PreviewRebuildEffect(computedFrameCount: 2, kernelExecuted: false, linePreviewImagesDirty: true)
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeFrames(count: Int) -> [PreviewFrameDescriptor] {
        (0 ..< count).map { i in
            PreviewFrameDescriptor(
                frameID: UUID(),
                orderIndex: i,
                hasComputedOverlay: i == 0
            )
        }
    }
}
