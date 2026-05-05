// ExtractionClient.swift
// Layer: ColorAnimaAppEngine — public app-side client wrapping the Bridge call.
// Translates between public app DTOs and Bridge DTOs.
// Does NOT import ColorAnimaKernel directly; all kernel access goes via the Bridge.

import ColorAnimaKernelBridge
import Foundation

// MARK: - AppEngine-side DTOs

/// Per-frame extraction summary for a single frame.
public struct ExtractionFrameReport: Equatable, Sendable {
    /// Stable identifier for this frame.
    public let frameID: UUID
    /// Number of regions detected in this frame.
    public let regionCount: Int
    /// Number of fill boundary candidates identified.
    public let additionalRegionCount: Int

    public init(frameID: UUID, regionCount: Int, additionalRegionCount: Int) {
        self.frameID = frameID
        self.regionCount = regionCount
        self.additionalRegionCount = additionalRegionCount
    }
}

/// Aggregate extraction report returned to app-side callers.
public struct ExtractionApplyReport: Equatable, Sendable {
    /// Per-frame reports, ordered by frame insertion.
    public let frameReports: [ExtractionFrameReport]
    /// Total regions detected across all frames.
    public let totalRegionCount: Int
    /// Total fill candidates across all frames.
    public let totalAdditionalRegionCount: Int
    /// Whether the kernel executed the pass (false when running in unavailable mode).
    public let kernelExecuted: Bool

    public init(
        frameReports: [ExtractionFrameReport],
        totalRegionCount: Int,
        totalAdditionalRegionCount: Int,
        kernelExecuted: Bool
    ) {
        self.frameReports = frameReports
        self.totalRegionCount = totalRegionCount
        self.totalAdditionalRegionCount = totalAdditionalRegionCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Public frame descriptor used by app-side callers of ExtractionClient.
public struct ExtractionClientFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int

    public init(frameID: UUID, orderIndex: Int) {
        self.frameID = frameID
        self.orderIndex = orderIndex
    }
}

/// Parameters for an extraction pass passed to the client.
public struct ExtractionClientRequest: Equatable, Sendable {
    /// Ordered input frames to extract.
    public let frames: [ExtractionClientFrameInput]
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int

    public init(frames: [ExtractionClientFrameInput], canvasWidth: Int, canvasHeight: Int) {
        self.frames = frames
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}

// MARK: - Client

/// App-side client for the extraction Bridge.
///
/// Wraps ExtractionBridge and translates between public app DTOs and Bridge DTOs.
/// Callers never interact with Bridge types directly.
///
/// When the kernel binary is not linked or the activation call cannot execute,
/// run() returns a zero-count report with kernelExecuted = false, allowing
/// callers to fall back gracefully.
public struct ExtractionClient: Sendable {
    private let bridge: ExtractionBridge

    public init(bridge: ExtractionBridge = ExtractionBridge()) {
        self.bridge = bridge
    }

    /// Whether the underlying kernel function is available.
    public var isAvailable: Bool {
        bridge.isExtractionAvailable
    }

    /// Runs an extraction pass and returns an apply report.
    ///
    /// Returns a zero-count report with kernelExecuted = false when the kernel
    /// activation call is unavailable. The coordinator layer uses this to fall
    /// back without crashing.
    public func run(request: ExtractionClientRequest) -> ExtractionApplyReport {
        let bridgeRequest = ExtractionRequest(
            frames: request.frames.map {
                ExtractionFrameInput(frameID: $0.frameID, orderIndex: $0.orderIndex)
            },
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )

        switch bridge.run(request: bridgeRequest) {
        case .success(let result):
            let reports = result.frameResults.values.map {
                ExtractionFrameReport(
                    frameID: $0.frameID,
                    regionCount: $0.regionCount,
                    additionalRegionCount: $0.additionalRegionCount
                )
            }
            return ExtractionApplyReport(
                frameReports: reports,
                totalRegionCount: result.totalRegionCount,
                totalAdditionalRegionCount: result.totalAdditionalRegionCount,
                kernelExecuted: true
            )
        case .failure:
            return ExtractionApplyReport(
                frameReports: [],
                totalRegionCount: 0,
                totalAdditionalRegionCount: 0,
                kernelExecuted: false
            )
        }
    }

    /// Builds a user-visible feedback string for an apply report.
    public func feedbackMessage(for report: ExtractionApplyReport) -> String {
        guard report.kernelExecuted else {
            return "Extraction: kernel not available"
        }
        return "\(report.totalRegionCount) regions extracted across \(report.frameReports.count) frames"
    }
}
