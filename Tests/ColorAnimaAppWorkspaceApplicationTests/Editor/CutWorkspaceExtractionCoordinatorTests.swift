import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

@MainActor
final class CutWorkspaceExtractionCoordinatorTests: XCTestCase {
    func testPrepareExtractionBuildsInputFramesForLoadedOutlineArtwork() {
        let firstID = UUID()
        let secondID = UUID()
        let firstArtwork = makeArtwork(name: "first.png", width: 4, height: 4)
        let secondArtwork = makeArtwork(name: "second.png", width: 5, height: 5)

        let preparation = CutWorkspaceExtractionCoordinator.prepareExtraction(
            for: [firstID, secondID],
            frames: [
                CutWorkspaceExtractionFrameState(id: firstID, orderIndex: 0, outlineArtwork: firstArtwork),
                CutWorkspaceExtractionFrameState(id: secondID, orderIndex: 1, outlineArtwork: secondArtwork),
            ]
        )

        guard case let .ready(inputFrames) = preparation else {
            XCTFail("Expected ready preparation")
            return
        }

        XCTAssertEqual(inputFrames.map(\.id), [firstID, secondID])
        XCTAssertEqual(inputFrames.map { $0.outlineArtwork.url.lastPathComponent }, ["first.png", "second.png"])
    }

    func testPrepareExtractionReportsFrameLabelsForMissingArtwork() {
        let missingArtworkID = UUID()
        let unknownFrameID = UUID()

        let preparation = CutWorkspaceExtractionCoordinator.prepareExtraction(
            for: [missingArtworkID, unknownFrameID],
            frames: [
                CutWorkspaceExtractionFrameState(id: missingArtworkID, orderIndex: 4)
            ]
        )

        guard case let .missingArtwork(message, labels) = preparation else {
            XCTFail("Expected missing artwork preparation")
            return
        }

        XCTAssertEqual(labels, ["#005", unknownFrameID.uuidString])
        XCTAssertEqual(
            message,
            "Load outline artwork for all target frames before extracting. Missing: #005, \(unknownFrameID.uuidString)."
        )
    }

    func testExtractRegionsRunsExtractionAndRefreshesPresentation() async {
        let frameID = UUID()
        let artwork = makeArtwork(name: "outline.png", width: 6, height: 6)
        var extractedFrameIDs: [UUID] = []
        var didRefresh = false

        let outcome = await CutWorkspaceExtractionCoordinator.extractRegions(
            for: [frameID],
            frames: [
                CutWorkspaceExtractionFrameState(id: frameID, orderIndex: 0, outlineArtwork: artwork)
            ],
            runExtraction: { frames in
                extractedFrameIDs = frames.map(\.id)
            },
            refreshPresentation: {
                didRefresh = true
            }
        )

        XCTAssertEqual(outcome, .completed(frameCount: 1))
        XCTAssertEqual(extractedFrameIDs, [frameID])
        XCTAssertTrue(didRefresh)
    }

    func testFeedbackProgressMovesThroughWarmupPhaseAndClearsOnCompletion() async {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        var phase1TextDuringExtraction: String?
        var phase2TextAtPostSuccess: String?

        let outcome = await CutWorkspaceExtractionCoordinator.extractRegions(
            for: [],
            frames: [],
            feedback: feedback,
            runExtraction: { _ in
                phase1TextDuringExtraction = feedback.progressText
            },
            refreshPresentation: {},
            postSuccess: {
                phase2TextAtPostSuccess = feedback.progressText
            }
        )

        XCTAssertEqual(outcome, .completed(frameCount: 0))
        XCTAssertEqual(phase1TextDuringExtraction, CutWorkspaceExtractionCoordinator.extractionProgressText)
        XCTAssertEqual(phase2TextAtPostSuccess, CutWorkspaceExtractionCoordinator.warmupProgressText)
        XCTAssertEqual(feedback.state, .completed)
        XCTAssertNil(feedback.progressText)
    }

    func testFeedbackStartsQueuedBeforeExtractionRuns() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")

        XCTAssertEqual(feedback.state, .queued)
        XCTAssertNil(feedback.startedAt)
        XCTAssertFalse(feedback.isTerminal)
    }

    func testEmptyTargetFrameIDsCompletesWithoutCrashing() async {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        var extractedFrames: [CutWorkspaceExtractionInputFrame]?
        var didRefresh = false

        let outcome = await CutWorkspaceExtractionCoordinator.extractRegions(
            for: [],
            frames: [],
            feedback: feedback,
            runExtraction: { frames in
                extractedFrames = frames
            },
            refreshPresentation: {
                didRefresh = true
            }
        )

        XCTAssertEqual(outcome, .completed(frameCount: 0))
        XCTAssertEqual(extractedFrames?.count, 0)
        XCTAssertTrue(didRefresh)
        XCTAssertEqual(feedback.state, .completed)
        XCTAssertTrue(feedback.isTerminal)
    }

    func testExtractRegionsWithoutFeedbackRunsQuietly() async {
        var extractedFrames: [CutWorkspaceExtractionInputFrame]?
        var didRefresh = false

        let outcome = await CutWorkspaceExtractionCoordinator.extractRegions(
            for: [],
            frames: [],
            runExtraction: { frames in
                extractedFrames = frames
            },
            refreshPresentation: {
                didRefresh = true
            }
        )

        XCTAssertEqual(outcome, .completed(frameCount: 0))
        XCTAssertEqual(extractedFrames?.count, 0)
        XCTAssertTrue(didRefresh)
    }

    func testFeedbackWithoutPostSuccessSkipsWarmupPhaseAndClearsOnCompletion() async {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        var textDuringExtraction: String?
        var textDuringRefresh: String?

        let outcome = await CutWorkspaceExtractionCoordinator.extractRegions(
            for: [],
            frames: [],
            feedback: feedback,
            runExtraction: { _ in
                textDuringExtraction = feedback.progressText
            },
            refreshPresentation: {
                textDuringRefresh = feedback.progressText
            }
        )

        XCTAssertEqual(outcome, .completed(frameCount: 0))
        XCTAssertEqual(textDuringExtraction, CutWorkspaceExtractionCoordinator.extractionProgressText)
        XCTAssertEqual(textDuringRefresh, CutWorkspaceExtractionCoordinator.extractionProgressText)
        XCTAssertEqual(feedback.state, .completed)
        XCTAssertNil(feedback.progressText)
    }

    func testMissingArtworkFailsFeedbackAndSetsErrorMessage() async {
        let frameID = UUID()
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        var errorMessage: String?
        var didRunExtraction = false
        var didRefresh = false

        let outcome = await CutWorkspaceExtractionCoordinator.extractRegions(
            for: [frameID],
            frames: [
                CutWorkspaceExtractionFrameState(id: frameID, orderIndex: 2)
            ],
            feedback: feedback,
            setErrorMessage: { message in
                errorMessage = message
            },
            runExtraction: { _ in
                didRunExtraction = true
            },
            refreshPresentation: {
                didRefresh = true
            }
        )

        XCTAssertEqual(
            outcome,
            .failed(
                message: "Load outline artwork for all target frames before extracting. Missing: #003.",
                missingLabels: ["#003"]
            )
        )
        XCTAssertEqual(errorMessage, "Load outline artwork for all target frames before extracting. Missing: #003.")
        XCTAssertEqual(feedback.state, .failed(message: "Load outline artwork for all target frames before extracting. Missing: #003."))
        XCTAssertNil(feedback.progressText)
        XCTAssertTrue(feedback.isTerminal)
        XCTAssertNotEqual(feedback.state, .completed)
        XCTAssertFalse(didRunExtraction)
        XCTAssertFalse(didRefresh)
    }

    private func makeArtwork(name: String, width: Int, height: Int) -> ImportedArtwork {
        ImportedArtwork(
            url: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: false),
            cgImage: makeImage(width: width, height: height)
        )
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
