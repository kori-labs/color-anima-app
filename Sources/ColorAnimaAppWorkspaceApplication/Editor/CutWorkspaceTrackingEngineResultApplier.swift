import Foundation

public struct TrackingResultRecordState: Hashable, Equatable, Sendable {
    public var targetRegionID: UUID
    public var reviewState: ConfidenceReviewState
    public var confidenceValue: Double?
    public var reasonCodes: [TrackingReviewReasonCode]
    public var isManualCorrection: Bool
    public var assignedRegion: AssignmentSyncAssignment?
    public var hasResolvedAssignment: Bool

    public init(
        targetRegionID: UUID,
        reviewState: ConfidenceReviewState,
        confidenceValue: Double? = nil,
        reasonCodes: [TrackingReviewReasonCode] = [],
        isManualCorrection: Bool = false,
        assignedRegion: AssignmentSyncAssignment? = nil,
        hasResolvedAssignment: Bool? = nil
    ) {
        self.targetRegionID = targetRegionID
        self.reviewState = reviewState
        self.confidenceValue = confidenceValue
        self.reasonCodes = reasonCodes
        self.isManualCorrection = isManualCorrection
        self.assignedRegion = assignedRegion
        self.hasResolvedAssignment = hasResolvedAssignment ?? (assignedRegion != nil)
    }

    public var shouldApplyPropagatedAssignment: Bool {
        switch reviewState {
        case .tracked, .reviewNeeded:
            return isManualCorrection == false && assignedRegion != nil
        case .unresolved:
            return false
        }
    }

    public var persistedRecord: PersistedTrackingRecordState {
        PersistedTrackingRecordState(
            regionID: targetRegionID,
            reviewState: reviewState,
            confidenceValue: confidenceValue,
            reasonCodes: reasonCodes,
            isManualCorrection: isManualCorrection,
            hasResolvedAssignment: hasResolvedAssignment
        )
    }

    public func queueItem(frameID: UUID) -> CutWorkspaceTrackingQueueItemState? {
        switch reviewState {
        case .tracked:
            return nil
        case .reviewNeeded:
            break
        case .unresolved:
            guard isManualCorrection == false else { return nil }
        }

        return CutWorkspaceTrackingQueueItemState(
            frameID: frameID,
            regionID: targetRegionID,
            reviewState: reviewState,
            reasonCodes: reasonCodes,
            hasResolvedAssignment: hasResolvedAssignment
        )
    }
}

public struct TrackingResultFrameState: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var reviewState: ConfidenceReviewState
    public var records: [TrackingResultRecordState]

    public init(
        id: UUID,
        reviewState: ConfidenceReviewState,
        records: [TrackingResultRecordState] = []
    ) {
        self.id = id
        self.reviewState = reviewState
        self.records = records
    }
}

public struct TrackingRunResultState: Hashable, Equatable, Sendable {
    public var frameResultsByID: [UUID: TrackingResultFrameState]
    public var promotedAnchorFrameIDs: [UUID]

    public init(
        frameResults: [TrackingResultFrameState],
        promotedAnchorFrameIDs: [UUID] = []
    ) {
        self.frameResultsByID = Dictionary(
            frameResults.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.promotedAnchorFrameIDs = promotedAnchorFrameIDs
    }
}

public struct TrackingResultApplication: Hashable, Equatable, Sendable {
    public var updatedFrameIDs: [UUID]
    public var unresolvedFrameIDs: [UUID]
    public var sessionState: CutWorkspaceTrackingSessionState

    public init(
        updatedFrameIDs: [UUID],
        unresolvedFrameIDs: [UUID],
        sessionState: CutWorkspaceTrackingSessionState
    ) {
        self.updatedFrameIDs = updatedFrameIDs
        self.unresolvedFrameIDs = unresolvedFrameIDs
        self.sessionState = sessionState
    }
}

public enum CutWorkspaceTrackingEngineResultApplier {
    @discardableResult
    public static func applyRunResult(
        _ runResult: TrackingRunResultState,
        snapshotFrames: [TrackingInputFrameState],
        to frames: inout [TrackingInputFrameState]
    ) -> TrackingResultApplication {
        var updatedFrameIDs: [UUID] = []
        var unresolvedFrameIDs: [UUID] = []
        var queueItems: [CutWorkspaceTrackingQueueItemState] = []

        let orderedSnapshots = sortedFrames(snapshotFrames)
        for snapshotFrame in orderedSnapshots {
            guard let resultFrame = runResult.frameResultsByID[snapshotFrame.id],
                  let frameIndex = frames.firstIndex(where: { $0.id == snapshotFrame.id }) else {
                continue
            }

            var updatedFrame = snapshotFrame
            updatedFrame.trackingRecords = resultFrame.records.map(\.persistedRecord)
            applyPropagatedAssignments(from: resultFrame.records, to: &updatedFrame)
            frames[frameIndex] = updatedFrame
            updatedFrameIDs.append(snapshotFrame.id)

            if resultFrame.reviewState == .unresolved {
                unresolvedFrameIDs.append(snapshotFrame.id)
            }

            queueItems.append(
                contentsOf: resultFrame.records.compactMap {
                    $0.queueItem(frameID: snapshotFrame.id)
                }
            )
        }

        let sessionState = CutWorkspaceTrackingSessionState(
            runStatus: .completed,
            lastRunResult: TrackingRunResult(
                updatedFrameIDs: updatedFrameIDs,
                unresolvedFrameIDs: unresolvedFrameIDs,
                promotedAnchorFrameIDs: runResult.promotedAnchorFrameIDs,
                reviewItemCount: queueItems.count
            ),
            queueState: queueItems.isEmpty ? nil : CutWorkspaceTrackingQueueState(queueItems: queueItems),
            promotedAnchorFrameIDs: runResult.promotedAnchorFrameIDs,
            excludedAnchorFrameIDs: unresolvedFrameIDs
        )

        return TrackingResultApplication(
            updatedFrameIDs: updatedFrameIDs,
            unresolvedFrameIDs: unresolvedFrameIDs,
            sessionState: sessionState
        )
    }

    @discardableResult
    public static func applyCancelledRun(
        framesProcessed: Int,
        framesTotal: Int,
        to sessionState: inout CutWorkspaceTrackingSessionState?
    ) -> CutWorkspaceTrackingSessionState {
        var updatedState = sessionState ?? CutWorkspaceTrackingSessionState()
        updatedState.runStatus = .cancelled(
            framesProcessed: max(0, framesProcessed),
            framesTotal: max(0, framesTotal)
        )
        sessionState = updatedState
        return updatedState
    }

    private static func sortedFrames(
        _ frames: [TrackingInputFrameState]
    ) -> [TrackingInputFrameState] {
        frames.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }

    private static func applyPropagatedAssignments(
        from records: [TrackingResultRecordState],
        to frame: inout TrackingInputFrameState
    ) {
        for record in records where record.shouldApplyPropagatedAssignment {
            guard let assignment = record.assignedRegion,
                  let regionIndex = frame.regions.firstIndex(where: { $0.id == record.targetRegionID }) else {
                continue
            }
            frame.regions[regionIndex].assignment = assignment
        }
    }
}
