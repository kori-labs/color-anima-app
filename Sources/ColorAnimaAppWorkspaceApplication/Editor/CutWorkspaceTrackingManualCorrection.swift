import Foundation

public enum CutWorkspaceTrackingManualCorrection {
    public struct ManualCorrectionTarget: Hashable, Equatable, Sendable {
        public var frameID: UUID
        public var regionID: UUID

        public init(frameID: UUID, regionID: UUID) {
            self.frameID = frameID
            self.regionID = regionID
        }
    }

    public struct ManualReassignmentSelection: Hashable, Equatable, Sendable {
        public var subsetID: UUID
        public var groupID: UUID
        public var statusName: String

        public init(subsetID: UUID, groupID: UUID, statusName: String) {
            self.subsetID = subsetID
            self.groupID = groupID
            self.statusName = statusName
        }
    }

    public enum ManualCorrectionKind: Hashable, Equatable, Sendable {
        case acceptance
        case reassignment(ManualReassignmentSelection)
    }

    public struct ManualCorrectionRequest: Hashable, Equatable, Sendable {
        public var target: ManualCorrectionTarget
        public var kind: ManualCorrectionKind
        public var promoteToAnchor: Bool

        public init(
            target: ManualCorrectionTarget,
            kind: ManualCorrectionKind,
            promoteToAnchor: Bool = false
        ) {
            self.target = target
            self.kind = kind
            self.promoteToAnchor = promoteToAnchor
        }
    }

    public struct ManualCorrectionApplication: Hashable, Equatable, Sendable {
        public var request: ManualCorrectionRequest
        public var removedQueueItem: Bool
        public var queueCursor: TrackingQueueCursor?
        public var remainingQueueItemCount: Int

        public init(
            request: ManualCorrectionRequest,
            removedQueueItem: Bool,
            queueCursor: TrackingQueueCursor?,
            remainingQueueItemCount: Int
        ) {
            self.request = request
            self.removedQueueItem = removedQueueItem
            self.queueCursor = queueCursor
            self.remainingQueueItemCount = max(0, remainingQueueItemCount)
        }
    }

    public static func applyTrackingManualCorrection(
        target: ManualCorrectionTarget,
        kind: ManualCorrectionKind,
        promoteToAnchor: Bool = false,
        in sessionState: inout CutWorkspaceTrackingSessionState,
        applyCorrection: (_ request: ManualCorrectionRequest) -> Bool,
        refreshOverlay: () -> Void
    ) -> ManualCorrectionApplication? {
        let request = ManualCorrectionRequest(
            target: target,
            kind: kind,
            promoteToAnchor: promoteToAnchor
        )

        guard applyCorrection(request) else {
            return nil
        }

        return finishCorrection(request, in: &sessionState, refreshOverlay: refreshOverlay)
    }

    public static func applyCurrentQueueAcceptance(
        promoteToAnchor: Bool = false,
        in sessionState: inout CutWorkspaceTrackingSessionState,
        frames: [CutWorkspaceTrackingQueueFrame],
        applyAcceptance: (_ target: ManualCorrectionTarget, _ promoteToAnchor: Bool) -> Bool,
        refreshOverlay: () -> Void
    ) -> ManualCorrectionApplication? {
        guard let queueItem = sessionState.currentQueueItem,
              canAcceptQueueItem(
                frameID: queueItem.frameID,
                regionID: queueItem.regionID,
                in: sessionState,
                frames: frames
              ) else {
            return nil
        }

        let target = ManualCorrectionTarget(frameID: queueItem.frameID, regionID: queueItem.regionID)
        return applyTrackingManualCorrection(
            target: target,
            kind: .acceptance,
            promoteToAnchor: promoteToAnchor,
            in: &sessionState,
            applyCorrection: { request in
                applyAcceptance(request.target, request.promoteToAnchor)
            },
            refreshOverlay: refreshOverlay
        )
    }

    public static func applyCurrentQueueReassignment(
        subsetID: UUID,
        groupID: UUID,
        statusName: String,
        promoteToAnchor: Bool = false,
        in sessionState: inout CutWorkspaceTrackingSessionState,
        frames: [CutWorkspaceTrackingQueueFrame],
        applyReassignment: (
            _ target: ManualCorrectionTarget,
            _ selection: ManualReassignmentSelection,
            _ promoteToAnchor: Bool
        ) -> Bool,
        refreshOverlay: () -> Void
    ) -> ManualCorrectionApplication? {
        guard let queueItem = sessionState.currentQueueItem,
              canReassignQueueItem(
                frameID: queueItem.frameID,
                regionID: queueItem.regionID,
                selectedSubsetID: subsetID,
                in: sessionState,
                frames: frames
              ) else {
            return nil
        }

        let target = ManualCorrectionTarget(frameID: queueItem.frameID, regionID: queueItem.regionID)
        let selection = ManualReassignmentSelection(
            subsetID: subsetID,
            groupID: groupID,
            statusName: statusName
        )

        return applyTrackingManualCorrection(
            target: target,
            kind: .reassignment(selection),
            promoteToAnchor: promoteToAnchor,
            in: &sessionState,
            applyCorrection: { request in
                applyReassignment(request.target, selection, request.promoteToAnchor)
            },
            refreshOverlay: refreshOverlay
        )
    }

    public static func canAcceptQueueItem(
        frameID: UUID,
        regionID: UUID,
        in sessionState: CutWorkspaceTrackingSessionState,
        frames: [CutWorkspaceTrackingQueueFrame]
    ) -> Bool {
        guard let queueItem = queueItem(frameID: frameID, regionID: regionID, in: sessionState),
              queueItem.hasResolvedAssignment,
              isManualOverride(frameID: frameID, regionID: regionID, frames: frames) == false else {
            return false
        }

        return true
    }

    public static func canReassignQueueItem(
        frameID: UUID,
        regionID: UUID,
        selectedSubsetID: UUID?,
        in sessionState: CutWorkspaceTrackingSessionState,
        frames: [CutWorkspaceTrackingQueueFrame]
    ) -> Bool {
        guard selectedSubsetID != nil,
              queueItem(frameID: frameID, regionID: regionID, in: sessionState) != nil,
              isManualOverride(frameID: frameID, regionID: regionID, frames: frames) == false else {
            return false
        }

        return true
    }

    private static func finishCorrection(
        _ request: ManualCorrectionRequest,
        in sessionState: inout CutWorkspaceTrackingSessionState,
        refreshOverlay: () -> Void
    ) -> ManualCorrectionApplication {
        let previousCount = sessionState.regionQueueItems.count
        sessionState = sessionState.removingQueueItem(
            frameID: request.target.frameID,
            regionID: request.target.regionID
        )
        let remainingCount = sessionState.regionQueueItems.count
        refreshOverlay()

        return ManualCorrectionApplication(
            request: request,
            removedQueueItem: remainingCount < previousCount,
            queueCursor: sessionState.queueCursor,
            remainingQueueItemCount: remainingCount
        )
    }

    private static func queueItem(
        frameID: UUID,
        regionID: UUID,
        in sessionState: CutWorkspaceTrackingSessionState
    ) -> CutWorkspaceTrackingQueueItemState? {
        sessionState.regionQueueItems.first { item in
            item.frameID == frameID && item.regionID == regionID
        }
    }

    private static func isManualOverride(
        frameID: UUID,
        regionID: UUID,
        frames: [CutWorkspaceTrackingQueueFrame]
    ) -> Bool? {
        frames
            .first { $0.id == frameID }?
            .regions
            .first { $0.id == regionID }?
            .isManualOverride
    }
}
