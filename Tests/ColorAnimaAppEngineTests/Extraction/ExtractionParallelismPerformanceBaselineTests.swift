// Performance baseline for sequential vs parallel multi-frame extraction
// timing through the public ExtractionClient API. Skips unless
// COLOR_ANIMA_PERF_TRACE=1 is set.

import ColorAnimaAppEngine
import Foundation
import XCTest

final class ExtractionParallelismPerformanceBaselineTests: XCTestCase {

    func testCaptureMultiFrameExtractionParallelismBaseline() async throws {
        try requirePerformanceTraceEnabled()

        let frameCount = 6
        let width = 1024
        let height = 1024

        let frameIDs = (0 ..< frameCount).map { _ in UUID() }

        // Sequential pass: run each frame independently in order.
        let sequentialResult = await measureNanoseconds {
            for (index, frameID) in frameIDs.enumerated() {
                let client = ExtractionClient()
                let request = ExtractionClientRequest(
                    frames: [ExtractionClientFrameInput(frameID: frameID, orderIndex: index)],
                    canvasWidth: width,
                    canvasHeight: height
                )
                _ = client.run(request: request)
            }
        }

        // Parallel pass: submit all frames in a single batch request.
        let parallelResult = await measureNanoseconds {
            let client = ExtractionClient()
            let frames = frameIDs.enumerated().map { index, id in
                ExtractionClientFrameInput(frameID: id, orderIndex: index)
            }
            let request = ExtractionClientRequest(
                frames: frames,
                canvasWidth: width,
                canvasHeight: height
            )
            _ = client.run(request: request)
        }

        // Capture region counts for output formatting.
        let parallelReport = ExtractionClient().run(request: ExtractionClientRequest(
            frames: frameIDs.enumerated().map { ExtractionClientFrameInput(frameID: $1, orderIndex: $0) },
            canvasWidth: width,
            canvasHeight: height
        ))
        let regionCounts = parallelReport.frameReports.map(\.regionCount)
        let regionCountsText = regionCounts.isEmpty
            ? (0 ..< frameCount).map { _ in "0" }.joined(separator: ",")
            : regionCounts.map(String.init).joined(separator: ",")

        let sequentialTotal = sequentialResult
        let parallelTotal = parallelResult
        let sequentialAverage = sequentialTotal / UInt64(max(frameCount, 1))
        let parallelAverage = parallelTotal / UInt64(max(frameCount, 1))
        let speedup = Double(sequentialTotal) / Double(max(parallelTotal, 1))

        print("[perf] multi-frame-extraction sequential frames=\(frameCount) totalNs=\(sequentialTotal) avgPerFrameNs=\(sequentialAverage)")
        print("[perf] multi-frame-extraction parallel frames=\(frameCount) totalNs=\(parallelTotal) avgPerFrameNs=\(parallelAverage)")
        print(String(format: "[perf] multi-frame-extraction speedup frames=%d ratio=%.4f", frameCount, speedup))
        print("[perf] multi-frame-extraction regionCounts frames=\(frameCount) values=\(regionCountsText)")
    }

    // MARK: - Helpers

    private func requirePerformanceTraceEnabled() throws {
        guard ProcessInfo.processInfo.environment["COLOR_ANIMA_PERF_TRACE"] == "1" else {
            throw XCTSkip("Set COLOR_ANIMA_PERF_TRACE=1 to capture extraction parallelism baselines.")
        }
    }

    private func measureNanoseconds(
        _ operation: @escaping () async -> Void
    ) async -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        await operation()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }
}
