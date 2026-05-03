import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

@MainActor
final class MultiImageImportCoordinatorTests: XCTestCase {
    func testCommitsValidFramesInIndexOrderEvenWhenResultsArriveOutOfOrder() async {
        let frameIDs = [UUID(), UUID(), UUID()]
        let progress = MultiImageImportProgress()
        progress.beginRun(total: 3)
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        feedback.markRunning()
        var committed: [UUID] = []
        var selectedFrameID: UUID?
        var syncCount = 0

        let result = await MultiImageImportCoordinator.run(
            urls: makeURLs(count: 3),
            targetFrameIDs: frameIDs,
            expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
            progress: progress,
            feedback: feedback,
            results: makeStream([
                .success(index: 1, url: makeURL(index: 1), payload: makePayload(name: "frame-2.png")),
                .success(index: 0, url: makeURL(index: 0), payload: makePayload(name: "frame-1.png")),
                .success(index: 2, url: makeURL(index: 2), payload: makePayload(name: "frame-3.png")),
            ]),
            commit: { request in
                committed.append(request.frameID)
            },
            selectFrame: { frameID in
                selectedFrameID = frameID
            },
            syncFromWorkspace: {
                syncCount += 1
            }
        )

        XCTAssertEqual(committed, frameIDs)
        XCTAssertEqual(selectedFrameID, frameIDs[0])
        XCTAssertEqual(progress.decoded, 3)
        XCTAssertEqual(progress.committed, 3)
        XCTAssertEqual(progress.failed, 0)
        XCTAssertEqual(feedback.state, .completed)
        XCTAssertEqual(result.committedCount, 3)
        XCTAssertEqual(result.selectedFrameID, frameIDs[0])
        XCTAssertGreaterThanOrEqual(syncCount, 1)
    }

    func testFailureSkipsIndexAndAllowsLaterSuccessToCommit() async {
        let frameIDs = [UUID(), UUID(), UUID()]
        let progress = MultiImageImportProgress()
        progress.beginRun(total: 3)
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        feedback.markRunning()
        var committed: [UUID] = []
        var errorMessage: String?

        let result = await MultiImageImportCoordinator.run(
            urls: makeURLs(count: 3),
            targetFrameIDs: frameIDs,
            expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
            progress: progress,
            feedback: feedback,
            results: makeStream([
                .success(index: 0, url: makeURL(index: 0), payload: makePayload(name: "frame-1.png")),
                .failure(index: 1, url: makeURL(index: 1), message: "Could not decode the image file."),
                .success(index: 2, url: makeURL(index: 2), payload: makePayload(name: "frame-3.png")),
            ]),
            commit: { request in
                committed.append(request.frameID)
            },
            getErrorMessage: { errorMessage },
            setErrorMessage: { errorMessage = $0 }
        )

        XCTAssertEqual(committed, [frameIDs[0], frameIDs[2]])
        XCTAssertEqual(errorMessage, "Frame #002: Could not decode the image file.")
        XCTAssertEqual(progress.decoded, 2)
        XCTAssertEqual(progress.committed, 2)
        XCTAssertEqual(progress.failed, 1)
        XCTAssertEqual(feedback.state, .completed)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(result.committedCount, 2)
    }

    func testValidationFailureRecordsFrameErrorWithoutCommit() async {
        let frameID = UUID()
        let progress = MultiImageImportProgress()
        progress.beginRun(total: 1)
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        feedback.markRunning()
        var didCommit = false
        var errorMessage: String?

        let result = await MultiImageImportCoordinator.run(
            urls: [makeURL(index: 0)],
            targetFrameIDs: [frameID],
            expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
            progress: progress,
            feedback: feedback,
            results: makeStream([
                .success(index: 0, url: makeURL(index: 0), payload: makePayload(name: "invalid.png", width: 3, height: 2))
            ]),
            commit: { _ in
                didCommit = true
            },
            getErrorMessage: { errorMessage },
            setErrorMessage: { errorMessage = $0 }
        )

        XCTAssertFalse(didCommit)
        XCTAssertEqual(
            errorMessage,
            "Frame #001: Outline image must match the project resolution of 2x2. Imported artwork is 3x2."
        )
        XCTAssertEqual(progress.decoded, 1)
        XCTAssertEqual(progress.committed, 0)
        XCTAssertEqual(progress.failed, 1)
        XCTAssertEqual(
            feedback.state,
            .failed(message: "Frame #001: Outline image must match the project resolution of 2x2. Imported artwork is 3x2.")
        )
        XCTAssertEqual(result.failedCount, 1)
    }

    func testCommitFailureAggregatesErrorAndAllowsLaterSuccess() async {
        let frameIDs = [UUID(), UUID()]
        let progress = MultiImageImportProgress()
        progress.beginRun(total: 2)
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        feedback.markRunning()
        var committed: [UUID] = []
        var errorMessage: String?

        let result = await MultiImageImportCoordinator.run(
            urls: makeURLs(count: 2),
            targetFrameIDs: frameIDs,
            expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
            progress: progress,
            feedback: feedback,
            results: makeStream([
                .success(index: 0, url: makeURL(index: 0), payload: makePayload(name: "frame-1.png")),
                .success(index: 1, url: makeURL(index: 1), payload: makePayload(name: "frame-2.png")),
            ]),
            commit: { request in
                if request.index == 0 {
                    throw ImportTestError.commitFailed
                }
                committed.append(request.frameID)
            },
            getErrorMessage: { errorMessage },
            setErrorMessage: { errorMessage = $0 }
        )

        XCTAssertEqual(committed, [frameIDs[1]])
        XCTAssertEqual(errorMessage, "Frame #001: Commit failed")
        XCTAssertEqual(progress.decoded, 2)
        XCTAssertEqual(progress.committed, 1)
        XCTAssertEqual(progress.failed, 1)
        XCTAssertEqual(feedback.state, .completed)
        XCTAssertEqual(result.committedCount, 1)
        XCTAssertEqual(result.failedCount, 1)
    }

    func testCancellationDeletesUncommittedCreatedFrames() async {
        let frameIDs = [UUID(), UUID(), UUID()]
        let progress = MultiImageImportProgress()
        progress.beginRun(total: 3)
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        feedback.markRunning(cancelHandle: LongRunningActionCancelHandle {})
        var committed: [UUID] = []
        var deleted: [UUID] = []

        let result = await MultiImageImportCoordinator.run(
            urls: makeURLs(count: 3),
            targetFrameIDs: frameIDs,
            createdFrameIDs: [frameIDs[1], frameIDs[2]],
            expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
            progress: progress,
            feedback: feedback,
            results: makeStream([
                .success(index: 0, url: makeURL(index: 0), payload: makePayload(name: "frame-1.png")),
                .success(index: 1, url: makeURL(index: 1), payload: makePayload(name: "frame-2.png")),
            ]),
            commit: { request in
                committed.append(request.frameID)
                if request.index == 0 {
                    feedback.markCancelled()
                }
            },
            deleteCreatedFrames: { frameIDs in
                deleted = frameIDs
            }
        )

        XCTAssertEqual(committed, [frameIDs[0]])
        XCTAssertEqual(deleted, [frameIDs[1], frameIDs[2]])
        XCTAssertEqual(feedback.state, .cancelled)
        XCTAssertEqual(result.deletedFrameIDs, [frameIDs[1], frameIDs[2]])
        XCTAssertTrue(result.wasCancelled)
    }

    private func makeStream(_ events: [StreamEvent]) -> AsyncStream<MultiImageImportFrameLoadResult> {
        AsyncStream { continuation in
            Task { @MainActor in
                for event in events {
                    switch event {
                    case let .result(result):
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }
        }
    }

    private func makePayload(
        name: String,
        width: Int = 2,
        height: Int = 2
    ) -> MultiImageImportFramePayload {
        MultiImageImportFramePayload(
            outlineArtwork: ImportedArtwork(
                url: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: false),
                cgImage: makeImage(width: width, height: height)
            )
        )
    }

    private func makeURLs(count: Int) -> [URL] {
        (0..<count).map(makeURL(index:))
    }

    private func makeURL(index: Int) -> URL {
        URL(fileURLWithPath: "/tmp/frame-\(index + 1).png", isDirectory: false)
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.indices.filter { $0 % 4 == 3 }.forEach { pixels[$0] = 255 }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}

private enum StreamEvent {
    case result(MultiImageImportFrameLoadResult)

    static func success(
        index: Int,
        url: URL,
        payload: MultiImageImportFramePayload
    ) -> StreamEvent {
        .result(.success(index: index, url: url, payload: payload))
    }

    static func failure(index: Int, url: URL, message: String) -> StreamEvent {
        .result(.failure(index: index, url: url, message: message))
    }
}

private enum ImportTestError: LocalizedError {
    case commitFailed

    var errorDescription: String? {
        switch self {
        case .commitFailed:
            "Commit failed"
        }
    }
}
