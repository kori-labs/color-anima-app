import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest

// MARK: - Stub client

private struct StubPrewarmClient: PrewarmClientProtocol {
    let kernelExecuted: Bool

    func run(
        frames: [PrewarmCoordinatorFrameInput],
        canvasWidth: Int,
        canvasHeight: Int,
        priorityTier: PrewarmCoordinatorPriorityTier
    ) -> PrewarmCoordinatorApplyReport {
        PrewarmCoordinatorApplyReport(
            computedFrameCount: kernelExecuted ? frames.count : 0,
            kernelExecuted: kernelExecuted
        )
    }
}

// MARK: - Tests

final class PrewarmEngineCoordinatorTests: XCTestCase {

    // MARK: - Active frame is excluded

    func testPrewarmExcludesActiveFrame() {
        let activeFrameID = UUID()
        let inactiveFrameID = UUID()
        let frames = [
            PrewarmFrameDescriptor(frameID: activeFrameID, orderIndex: 0),
            PrewarmFrameDescriptor(frameID: inactiveFrameID, orderIndex: 1),
        ]
        let client = StubPrewarmClient(kernelExecuted: false)

        let effect = PrewarmEngineCoordinator.prewarm(
            frames: frames,
            selectedFrameID: activeFrameID,
            canvas: PrewarmCanvasDescriptor(width: 4, height: 4),
            priority: .high,
            client: client
        )

        XCTAssertFalse(effect.frameEffects.contains { $0.frameID == activeFrameID },
                       "Active frame must not appear in prewarm frame effects")
        XCTAssertTrue(effect.frameEffects.contains { $0.frameID == inactiveFrameID })
    }

    // MARK: - Unavailable stub path

    func testPrewarmReturnsUnavailableEffectWhenKernelNotExposed() {
        let frames = makeFrames(count: 3)
        let client = StubPrewarmClient(kernelExecuted: false)

        let effect = PrewarmEngineCoordinator.prewarm(
            frames: frames,
            selectedFrameID: frames.first?.frameID,
            canvas: PrewarmCanvasDescriptor(width: 1920, height: 1080),
            priority: .high,
            client: client
        )

        XCTAssertFalse(effect.kernelExecuted)
        XCTAssertEqual(effect.computedFrameCount, 0)
        // Inactive frames are still listed in frameEffects (previewStateComputed = false)
        XCTAssertEqual(effect.frameEffects.count, frames.count - 1)
        XCTAssertTrue(effect.frameEffects.allSatisfy { !$0.previewStateComputed })
    }

    // MARK: - All frames inactive

    func testPrewarmWithAllInactiveFrames() {
        let frames = makeFrames(count: 3)
        let client = StubPrewarmClient(kernelExecuted: false)

        let effect = PrewarmEngineCoordinator.prewarm(
            frames: frames,
            selectedFrameID: nil,
            canvas: PrewarmCanvasDescriptor(width: 1920, height: 1080),
            priority: .low,
            client: client
        )

        XCTAssertEqual(effect.frameEffects.count, 3)
    }

    // MARK: - Empty frames returns empty effect

    func testPrewarmWithNoFramesReturnsEmptyEffect() {
        let client = StubPrewarmClient(kernelExecuted: false)
        let effect = PrewarmEngineCoordinator.prewarm(
            frames: [],
            selectedFrameID: nil,
            canvas: PrewarmCanvasDescriptor(width: 1920, height: 1080),
            priority: .high,
            client: client
        )
        XCTAssertTrue(effect.frameEffects.isEmpty)
        XCTAssertEqual(effect.computedFrameCount, 0)
        XCTAssertFalse(effect.kernelExecuted)
    }

    // MARK: - Zero canvas skips execution

    func testPrewarmWithZeroCanvasDimensionReturnsEmptyEffect() {
        let frames = makeFrames(count: 3)
        let client = StubPrewarmClient(kernelExecuted: false)

        let effect = PrewarmEngineCoordinator.prewarm(
            frames: frames,
            selectedFrameID: nil,
            canvas: PrewarmCanvasDescriptor(width: 0, height: 1080),
            priority: .high,
            client: client
        )

        XCTAssertTrue(effect.frameEffects.isEmpty)
        XCTAssertEqual(effect.computedFrameCount, 0)
    }

    // MARK: - shouldExcludeActiveFrame

    func testShouldExcludeActiveFrameReturnsTrueForMatch() {
        let id = UUID()
        XCTAssertTrue(PrewarmEngineCoordinator.shouldExcludeActiveFrame(id, selectedFrameID: id))
    }

    func testShouldExcludeActiveFrameReturnsFalseForNonMatch() {
        XCTAssertFalse(
            PrewarmEngineCoordinator.shouldExcludeActiveFrame(UUID(), selectedFrameID: UUID())
        )
    }

    func testShouldExcludeActiveFrameReturnsFalseWhenNoSelection() {
        XCTAssertFalse(
            PrewarmEngineCoordinator.shouldExcludeActiveFrame(UUID(), selectedFrameID: nil)
        )
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableEffect() {
        let effect = PrewarmEffect(frameEffects: [], computedFrameCount: 0, kernelExecuted: false)
        let message = PrewarmEngineCoordinator.feedbackMessage(for: effect)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(
            message.contains("not yet available") || message.contains("kernel"),
            "Expected kernel unavailability message, got: \(message)"
        )
    }

    func testFeedbackMessageForExecutedEffect() {
        let effect = PrewarmEffect(
            frameEffects: [],
            computedFrameCount: 4,
            kernelExecuted: true
        )
        let message = PrewarmEngineCoordinator.feedbackMessage(for: effect)
        XCTAssertTrue(message.contains("4"), "Expected frame count in message, got: \(message)")
    }

    // MARK: - All priority tiers

    func testAllPriorityTiersReachClientWithUnavailableResult() {
        let frames = makeFrames(count: 2)
        let client = StubPrewarmClient(kernelExecuted: false)
        let canvas = PrewarmCanvasDescriptor(width: 100, height: 100)

        for priority in [PrewarmSchedulePriority.high, .medium, .low] {
            let effect = PrewarmEngineCoordinator.prewarm(
                frames: frames,
                selectedFrameID: nil,
                canvas: canvas,
                priority: priority,
                client: client
            )
            XCTAssertFalse(effect.kernelExecuted, "Expected unavailable for priority \(priority)")
        }
    }

    // MARK: - DTO equality

    func testPrewarmFrameDescriptorEquality() {
        let id = UUID()
        let a = PrewarmFrameDescriptor(frameID: id, orderIndex: 1)
        let b = PrewarmFrameDescriptor(frameID: id, orderIndex: 1)
        XCTAssertEqual(a, b)
    }

    func testPrewarmCanvasDescriptorEquality() {
        let a = PrewarmCanvasDescriptor(width: 1920, height: 1080)
        let b = PrewarmCanvasDescriptor(width: 1920, height: 1080)
        XCTAssertEqual(a, b)
    }

    func testPrewarmFrameEffectEquality() {
        let id = UUID()
        let a = PrewarmFrameEffect(frameID: id, previewStateComputed: false)
        let b = PrewarmFrameEffect(frameID: id, previewStateComputed: false)
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeFrames(count: Int) -> [PrewarmFrameDescriptor] {
        (0 ..< count).map { i in
            PrewarmFrameDescriptor(frameID: UUID(), orderIndex: i)
        }
    }
}
