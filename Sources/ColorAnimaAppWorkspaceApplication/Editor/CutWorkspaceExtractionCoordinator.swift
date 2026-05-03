import Foundation

public struct CutWorkspaceExtractionFrameState: Sendable {
    public var id: UUID
    public var orderIndex: Int
    public var outlineArtwork: ImportedArtwork?

    public init(
        id: UUID = UUID(),
        orderIndex: Int,
        outlineArtwork: ImportedArtwork? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.outlineArtwork = outlineArtwork
    }

    public var displayLabel: String {
        String(format: "#%03d", max(orderIndex + 1, 1))
    }
}

public struct CutWorkspaceExtractionInputFrame: Sendable {
    public var id: UUID
    public var outlineArtwork: ImportedArtwork

    public init(id: UUID, outlineArtwork: ImportedArtwork) {
        self.id = id
        self.outlineArtwork = outlineArtwork
    }
}

public enum CutWorkspaceExtractionPreparation: Sendable {
    case ready([CutWorkspaceExtractionInputFrame])
    case missingArtwork(message: String, missingLabels: [String])
}

public enum CutWorkspaceExtractionRunOutcome: Equatable, Sendable {
    case completed(frameCount: Int)
    case failed(message: String, missingLabels: [String])
}

@MainActor
public enum CutWorkspaceExtractionCoordinator {
    public static let extractionProgressText = "Extracting Regions (1/2)"
    public static let warmupProgressText = "Warming up Frames (2/2)"

    public static func prepareExtraction(
        for targetFrameIDs: [UUID],
        frames: [CutWorkspaceExtractionFrameState]
    ) -> CutWorkspaceExtractionPreparation {
        var frameByID: [UUID: CutWorkspaceExtractionFrameState] = [:]
        for frame in frames where frameByID[frame.id] == nil {
            frameByID[frame.id] = frame
        }

        var inputFrames: [CutWorkspaceExtractionInputFrame] = []
        var missingLabels: [String] = []

        for frameID in targetFrameIDs {
            guard let frame = frameByID[frameID] else {
                missingLabels.append(frameID.uuidString)
                continue
            }
            guard let artwork = frame.outlineArtwork else {
                missingLabels.append(frame.displayLabel)
                continue
            }
            inputFrames.append(CutWorkspaceExtractionInputFrame(id: frameID, outlineArtwork: artwork))
        }

        guard missingLabels.isEmpty else {
            let summary = missingLabels.joined(separator: ", ")
            let message = "Load outline artwork for all target frames before extracting. Missing: \(summary)."
            return .missingArtwork(message: message, missingLabels: missingLabels)
        }

        return .ready(inputFrames)
    }

    @discardableResult
    public static func extractRegions(
        for targetFrameIDs: [UUID],
        frames: [CutWorkspaceExtractionFrameState],
        feedback: LongRunningActionFeedback? = nil,
        setErrorMessage: @MainActor (String) -> Void = { _ in },
        runExtraction: @MainActor ([CutWorkspaceExtractionInputFrame]) async -> Void,
        refreshPresentation: @MainActor () -> Void,
        postSuccess: (@MainActor () async -> Void)? = nil
    ) async -> CutWorkspaceExtractionRunOutcome {
        feedback?.markRunning()
        feedback?.progressText = extractionProgressText

        switch prepareExtraction(for: targetFrameIDs, frames: frames) {
        case let .missingArtwork(message, missingLabels):
            setErrorMessage(message)
            feedback?.markFailed(message: message)
            return .failed(message: message, missingLabels: missingLabels)

        case let .ready(inputFrames):
            await runExtraction(inputFrames)
            refreshPresentation()

            if postSuccess != nil {
                feedback?.progressText = warmupProgressText
            }
            await postSuccess?()

            feedback?.markCompleted()
            return .completed(frameCount: inputFrames.count)
        }
    }
}
