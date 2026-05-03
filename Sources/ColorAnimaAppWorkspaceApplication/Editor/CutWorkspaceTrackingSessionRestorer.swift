import Foundation

public struct PersistedTrackingRecordState: Hashable, Equatable, Sendable {
    public var regionID: UUID
    public var reviewState: ConfidenceReviewState
    public var confidenceValue: Double?
    public var reasonCodes: [TrackingReviewReasonCode]
    public var isManualCorrection: Bool
    public var hasResolvedAssignment: Bool

    public init(
        regionID: UUID,
        reviewState: ConfidenceReviewState,
        confidenceValue: Double? = nil,
        reasonCodes: [TrackingReviewReasonCode] = [],
        isManualCorrection: Bool = false,
        hasResolvedAssignment: Bool = false
    ) {
        self.regionID = regionID
        self.reviewState = reviewState
        self.confidenceValue = confidenceValue
        self.reasonCodes = reasonCodes
        self.isManualCorrection = isManualCorrection
        self.hasResolvedAssignment = hasResolvedAssignment
    }
}

public struct PersistedTrackingFrameState: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var orderIndex: Int
    public var records: [PersistedTrackingRecordState]

    public init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        records: [PersistedTrackingRecordState] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.records = records
    }
}

public enum CutWorkspaceTrackingSessionRestorer {
    public static func restoreSessionStateFromPersistedTracking(
        existingSessionState: CutWorkspaceTrackingSessionState?,
        frames: [PersistedTrackingFrameState],
        promotedAnchorFrameIDs: [UUID] = [],
        excludedAnchorFrameIDs: [UUID] = []
    ) -> CutWorkspaceTrackingSessionState? {
        guard existingSessionState == nil,
              frames.contains(where: { $0.records.isEmpty == false }) else {
            return existingSessionState
        }

        let queueItems = frames
            .sorted { lhs, rhs in
                if lhs.orderIndex == rhs.orderIndex {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.orderIndex < rhs.orderIndex
            }
            .flatMap(makeQueueItems)

        return CutWorkspaceTrackingSessionState(
            runStatus: .completed,
            lastRunResult: TrackingRunResult(reviewItemCount: queueItems.count),
            queueState: CutWorkspaceTrackingQueueState(queueItems: queueItems),
            promotedAnchorFrameIDs: promotedAnchorFrameIDs,
            excludedAnchorFrameIDs: excludedAnchorFrameIDs
        )
    }

    public static func hasTrackingContext(
        frameID: UUID,
        regionID: UUID,
        in frames: [PersistedTrackingFrameState]
    ) -> Bool {
        frames.first { $0.id == frameID }?
            .records
            .contains { $0.regionID == regionID } ?? false
    }

    private static func makeQueueItems(
        for frame: PersistedTrackingFrameState
    ) -> [CutWorkspaceTrackingQueueItemState] {
        frame.records.compactMap { record in
            guard shouldQueue(record) else { return nil }
            return CutWorkspaceTrackingQueueItemState(
                frameID: frame.id,
                regionID: record.regionID,
                reviewState: record.reviewState,
                reasonCodes: record.reasonCodes,
                hasResolvedAssignment: record.hasResolvedAssignment
            )
        }
    }

    private static func shouldQueue(_ record: PersistedTrackingRecordState) -> Bool {
        switch record.reviewState {
        case .tracked:
            return false
        case .reviewNeeded:
            return true
        case .unresolved:
            return record.isManualCorrection == false
        }
    }
}
