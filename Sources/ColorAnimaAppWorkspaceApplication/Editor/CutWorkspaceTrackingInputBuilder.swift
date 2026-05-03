import Foundation

public struct TrackingInputRegionState: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID { region.id }
    public var region: CanvasSelectionRegion
    public var assignment: AssignmentSyncAssignment?

    public init(
        region: CanvasSelectionRegion,
        assignment: AssignmentSyncAssignment? = nil
    ) {
        self.region = region
        self.assignment = assignment
    }

    public var isAssigned: Bool {
        assignment != nil
    }
}

public struct TrackingInputFrameState: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var orderIndex: Int
    public var regions: [TrackingInputRegionState]
    public var trackingRecords: [PersistedTrackingRecordState]

    public init(
        id: UUID = UUID(),
        orderIndex: Int,
        regions: [TrackingInputRegionState] = [],
        trackingRecords: [PersistedTrackingRecordState] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.regions = regions
        self.trackingRecords = trackingRecords
    }

    public var hasExtractedRegions: Bool {
        regions.isEmpty == false
    }

    public var hasAssignedRegions: Bool {
        regions.contains(where: \.isAssigned)
    }

    public var readinessFrame: CutWorkspaceTrackingReadinessFrame {
        CutWorkspaceTrackingReadinessFrame(
            id: id,
            hasExtractedRegions: hasExtractedRegions,
            hasAssignedRegions: hasAssignedRegions
        )
    }
}

public struct TrackingRunInputSnapshot: Hashable, Equatable, Sendable {
    public var orderedFrames: [TrackingInputFrameState]
    public var keyFrameIDs: [UUID]
    public var preferredReferenceFrameID: UUID?
    public var canvasResolution: ProjectCanvasResolution
    public var gapReviewPreflight: CutWorkspaceTrackingPreflightSummary?

    public init(
        orderedFrames: [TrackingInputFrameState],
        keyFrameIDs: [UUID],
        preferredReferenceFrameID: UUID?,
        canvasResolution: ProjectCanvasResolution,
        gapReviewPreflight: CutWorkspaceTrackingPreflightSummary?
    ) {
        self.orderedFrames = orderedFrames
        self.keyFrameIDs = keyFrameIDs
        self.preferredReferenceFrameID = preferredReferenceFrameID
        self.canvasResolution = canvasResolution
        self.gapReviewPreflight = gapReviewPreflight
    }

    public var totalFrameCount: Int {
        orderedFrames.count
    }

    public var canvasWidth: Int {
        canvasResolution.width
    }

    public var canvasHeight: Int {
        canvasResolution.height
    }
}

public enum CutWorkspaceTrackingInputBuilder {
    public static func makeRunInputs(
        frames: [TrackingInputFrameState],
        keyFrameIDs: [UUID],
        selectedFrameSelectionAnchorID: UUID? = nil,
        activeReferenceFrameID: UUID? = nil,
        selectedFrameID: UUID? = nil,
        canvasResolution: ProjectCanvasResolution,
        gapReviewSessions: [CutWorkspaceGapReviewFrameSession] = []
    ) -> TrackingRunInputSnapshot {
        let orderedFrames = sortedFrames(frames)
        let frameOrder = orderedFrames.map(\.id)
        let referenceSelection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: frameOrder,
            keyFrameIDs: keyFrameIDs,
            selectedFrameSelectionAnchorID: selectedFrameSelectionAnchorID,
            activeReferenceFrameID: activeReferenceFrameID,
            selectedFrameID: selectedFrameID
        )
        let effectiveSelection = CutWorkspaceTrackingReadiness.demoteReferenceFrameIDs(
            referenceIDs: referenceSelection.anchorFrameIDs,
            preferredID: referenceSelection.preferredFrameID,
            frames: orderedFrames.map(\.readinessFrame)
        )
        let gapReviewPreflight = CutWorkspaceTrackingPreflightSummary.aggregate(
            sessions: gapReviewSessions
        )

        return TrackingRunInputSnapshot(
            orderedFrames: orderedFrames,
            keyFrameIDs: effectiveSelection.effectiveReferenceFrameIDs,
            preferredReferenceFrameID: effectiveSelection.effectivePreferredReferenceFrameID,
            canvasResolution: canvasResolution,
            gapReviewPreflight: gapReviewPreflight
        )
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
}
