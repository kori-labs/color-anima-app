import Foundation

public enum CutWorkspaceTrackingInteractionCoordinator {
    public struct TrackingFocusTarget: Hashable, Equatable, Sendable {
        public let frameID: UUID
        public let regionID: UUID

        public init(frameID: UUID, regionID: UUID) {
            self.frameID = frameID
            self.regionID = regionID
        }
    }

    public static func navigateToQueueItem(
        at index: Int,
        queueState: inout CutWorkspaceTrackingQueueState?,
        frames: [CutWorkspaceTrackingQueueFrame]
    ) -> TrackingFocusTarget? {
        CutWorkspaceTrackingQueueNavigator.setQueueCursor(in: &queueState, to: index)
        return currentQueueFocusTarget(queueState: queueState, frames: frames)
    }

    public static func skipCurrentQueueItem(
        queueState: inout CutWorkspaceTrackingQueueState?,
        frames: [CutWorkspaceTrackingQueueFrame]
    ) -> TrackingFocusTarget? {
        guard let presentation = CutWorkspaceTrackingQueueNavigator.makeQueueNavigatorPresentation(
            state: queueState,
            frames: frames,
            selectedSubsetID: nil
        ) else {
            return nil
        }

        let nextIndex = min(presentation.currentIndex + 1, max(0, presentation.totalCount - 1))
        CutWorkspaceTrackingQueueNavigator.setQueueCursor(in: &queueState, to: nextIndex)
        return currentQueueFocusTarget(queueState: queueState, frames: frames)
    }

    public static func acceptCurrentQueueItem(
        queueState: CutWorkspaceTrackingQueueState?,
        frames: [CutWorkspaceTrackingQueueFrame],
        applyAcceptance: () -> Void,
        refreshOverlay: () -> Void
    ) -> TrackingFocusTarget? {
        applyAcceptance()
        refreshOverlay()
        return currentQueueFocusTarget(queueState: queueState, frames: frames)
    }

    public static func reassignCurrentQueueItem(
        subsetID: UUID,
        groupID: UUID,
        statusName: String,
        queueState: CutWorkspaceTrackingQueueState?,
        frames: [CutWorkspaceTrackingQueueFrame],
        applyReassignment: (_ subsetID: UUID, _ groupID: UUID, _ statusName: String) -> Void,
        refreshOverlay: () -> Void
    ) -> TrackingFocusTarget? {
        applyReassignment(subsetID, groupID, statusName)
        refreshOverlay()
        return currentQueueFocusTarget(queueState: queueState, frames: frames)
    }

    public static func acceptSelectedRegionTracking(
        selectedFrameID: UUID?,
        selectedRegionID: UUID?,
        promoteToAnchor: Bool,
        hasTrackingContext: (TrackingFocusTarget) -> Bool,
        hasResolvedAssignment: (TrackingFocusTarget) -> Bool,
        applyAcceptance: (_ target: TrackingFocusTarget, _ promoteToAnchor: Bool) -> Bool,
        refreshOverlay: () -> Void
    ) -> TrackingFocusTarget? {
        guard let target = selectedTrackingContext(
            selectedFrameID: selectedFrameID,
            selectedRegionID: selectedRegionID,
            hasTrackingContext: hasTrackingContext
        ),
              hasResolvedAssignment(target),
              applyAcceptance(target, promoteToAnchor) else {
            return nil
        }

        refreshOverlay()
        return target
    }

    public static func reassignSelectedRegionTracking(
        selectedFrameID: UUID?,
        selectedRegionID: UUID?,
        subsetID: UUID,
        groupID: UUID,
        statusName: String,
        promoteToAnchor: Bool,
        hasTrackingContext: (TrackingFocusTarget) -> Bool,
        applyReassignment: (
            _ target: TrackingFocusTarget,
            _ subsetID: UUID,
            _ groupID: UUID,
            _ statusName: String,
            _ promoteToAnchor: Bool
        ) -> Bool,
        refreshOverlay: () -> Void
    ) -> TrackingFocusTarget? {
        guard let target = selectedTrackingContext(
            selectedFrameID: selectedFrameID,
            selectedRegionID: selectedRegionID,
            hasTrackingContext: hasTrackingContext
        ),
              applyReassignment(target, subsetID, groupID, statusName, promoteToAnchor) else {
            return nil
        }

        refreshOverlay()
        return target
    }

    @discardableResult
    public static func applyTrackingReassignmentIfAvailable(
        frameID: UUID,
        regionID: UUID,
        subsetID: UUID,
        groupID: UUID,
        statusName: String,
        applyReassignment: (
            _ target: TrackingFocusTarget,
            _ subsetID: UUID,
            _ groupID: UUID,
            _ statusName: String
        ) -> Bool,
        refreshOverlay: () -> Void
    ) -> Bool {
        let target = TrackingFocusTarget(frameID: frameID, regionID: regionID)
        guard applyReassignment(target, subsetID, groupID, statusName) else {
            return false
        }

        refreshOverlay()
        return true
    }

    @discardableResult
    public static func markSelectedRegionUnresolved(
        selectedFrameID: UUID?,
        selectedRegionID: UUID?,
        hasTrackingContext: (TrackingFocusTarget) -> Bool,
        applyUnresolved: (_ target: TrackingFocusTarget) -> Bool,
        refreshOverlay: () -> Void
    ) -> TrackingFocusTarget? {
        guard let target = selectedTrackingContext(
            selectedFrameID: selectedFrameID,
            selectedRegionID: selectedRegionID,
            hasTrackingContext: hasTrackingContext
        ),
              applyUnresolved(target) else {
            return nil
        }

        refreshOverlay()
        return target
    }

    @discardableResult
    public static func applyTrackingSplitOverrideIfAvailable(
        for role: CutGuideRole,
        selectedFrameID: UUID?,
        selectedRegionID: UUID?,
        hasTrackingContext: (TrackingFocusTarget) -> Bool,
        applySplitOverride: (_ target: TrackingFocusTarget, _ role: CutGuideRole) -> Bool,
        refreshOverlay: () -> Void
    ) -> Bool {
        guard let target = selectedTrackingContext(
            selectedFrameID: selectedFrameID,
            selectedRegionID: selectedRegionID,
            hasTrackingContext: hasTrackingContext
        ),
              applySplitOverride(target, role) else {
            return false
        }

        refreshOverlay()
        return true
    }

    public static func currentQueueFocusTarget(
        queueState: CutWorkspaceTrackingQueueState?,
        frames: [CutWorkspaceTrackingQueueFrame]
    ) -> TrackingFocusTarget? {
        guard let item = CutWorkspaceTrackingQueueNavigator.makeQueueNavigatorPresentation(
            state: queueState,
            frames: frames,
            selectedSubsetID: nil
        )?.currentItem else {
            return nil
        }

        return TrackingFocusTarget(frameID: item.frameID, regionID: item.regionID)
    }

    public static func selectedTrackingContext(
        selectedFrameID: UUID?,
        selectedRegionID: UUID?,
        hasTrackingContext: (TrackingFocusTarget) -> Bool
    ) -> TrackingFocusTarget? {
        guard let selectedFrameID, let selectedRegionID else {
            return nil
        }

        let target = TrackingFocusTarget(frameID: selectedFrameID, regionID: selectedRegionID)
        guard hasTrackingContext(target) else {
            return nil
        }
        return target
    }
}
