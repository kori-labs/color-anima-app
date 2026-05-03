import Foundation

public struct CutWorkspaceTrackingQueueRegion: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String
    public var confidenceValue: Double?
    public var isManualOverride: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        confidenceValue: Double? = nil,
        isManualOverride: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.confidenceValue = confidenceValue
        self.isManualOverride = isManualOverride
    }
}

public struct CutWorkspaceTrackingQueueFrame: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var orderIndex: Int
    public var regions: [CutWorkspaceTrackingQueueRegion]

    public init(
        id: UUID = UUID(),
        orderIndex: Int,
        regions: [CutWorkspaceTrackingQueueRegion]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.regions = regions
    }
}

public struct CutWorkspaceTrackingQueueItemState: Hashable, Equatable, Sendable {
    public var frameID: UUID
    public var regionID: UUID
    public var reviewState: ConfidenceReviewState
    public var reasonCodes: [TrackingReviewReasonCode]
    public var hasResolvedAssignment: Bool

    public init(
        frameID: UUID,
        regionID: UUID,
        reviewState: ConfidenceReviewState,
        reasonCodes: [TrackingReviewReasonCode] = [],
        hasResolvedAssignment: Bool = false
    ) {
        self.frameID = frameID
        self.regionID = regionID
        self.reviewState = reviewState
        self.reasonCodes = reasonCodes
        self.hasResolvedAssignment = hasResolvedAssignment
    }
}

public struct CutWorkspaceTrackingQueueState: Hashable, Equatable, Sendable {
    public var queueItems: [CutWorkspaceTrackingQueueItemState]
    public var queueIndex: Int

    public init(
        queueItems: [CutWorkspaceTrackingQueueItemState],
        queueIndex: Int = 0
    ) {
        self.queueItems = queueItems
        self.queueIndex = queueIndex
    }

    public var clampedQueueIndex: Int {
        guard queueItems.isEmpty == false else {
            return 0
        }
        return min(max(0, queueIndex), queueItems.count - 1)
    }

    public var currentQueueItem: CutWorkspaceTrackingQueueItemState? {
        guard queueItems.isEmpty == false else {
            return nil
        }
        return queueItems[clampedQueueIndex]
    }
}

public enum CutWorkspaceTrackingQueueNavigator {
    public static func makeQueueNavigatorPresentation(
        state: CutWorkspaceTrackingQueueState?,
        frames: [CutWorkspaceTrackingQueueFrame],
        selectedSubsetID: UUID?
    ) -> TrackingQueueNavigatorPresentation? {
        guard let state,
              let queueItem = state.currentQueueItem,
              frame(for: queueItem.frameID, in: frames)?
                .regions
                .contains(where: { $0.id == queueItem.regionID }) == true else {
            return nil
        }

        let queueItems = state.queueItems
        let frameID = queueItem.frameID
        let regionID = queueItem.regionID
        let currentItem = makeQueueItemPresentation(for: queueItem, in: frames)

        return TrackingQueueNavigatorPresentation(
            frameID: frameID,
            regionID: regionID,
            currentIndex: state.clampedQueueIndex,
            totalCount: queueItems.count,
            currentItem: currentItem,
            items: queueItems.compactMap { makeQueueItemPresentation(for: $0, in: frames) },
            severity: queueItem.reviewState == .unresolved ? .unresolved : .reviewNeeded,
            canGoBackward: state.clampedQueueIndex > 0,
            canGoForward: state.clampedQueueIndex < queueItems.count - 1,
            canAccept: canAccept(queueItem, currentItem: currentItem),
            canReassign: canReassign(currentItem: currentItem, selectedSubsetID: selectedSubsetID),
            canSkip: state.clampedQueueIndex < queueItems.count - 1
        )
    }

    public static func moveQueueCursor(
        in state: inout CutWorkspaceTrackingQueueState?,
        delta: Int
    ) {
        guard var nextState = state,
              nextState.queueItems.isEmpty == false else {
            return
        }

        nextState.queueIndex = min(
            max(0, nextState.clampedQueueIndex + delta),
            nextState.queueItems.count - 1
        )
        state = nextState
    }

    public static func setQueueCursor(
        in state: inout CutWorkspaceTrackingQueueState?,
        to index: Int
    ) {
        guard var nextState = state,
              nextState.queueItems.isEmpty == false else {
            return
        }

        nextState.queueIndex = min(max(0, index), nextState.queueItems.count - 1)
        state = nextState
    }

    private static func makeQueueItemPresentation(
        for item: CutWorkspaceTrackingQueueItemState,
        in frames: [CutWorkspaceTrackingQueueFrame]
    ) -> TrackingQueueNavigatorItem? {
        guard let frame = frame(for: item.frameID, in: frames),
              let region = frame.regions.first(where: { $0.id == item.regionID }) else {
            return nil
        }

        let regionLabel = region.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        return TrackingQueueNavigatorItem(
            frameID: item.frameID,
            regionID: item.regionID,
            regionDisplayName: regionLabel.isEmpty ? shortRegionLabel(item.regionID) : regionLabel,
            frameOrderIndex: frame.orderIndex,
            confidenceValue: region.confidenceValue,
            reasonCodes: item.reasonCodes,
            isManualOverride: region.isManualOverride
        )
    }

    private static func frame(
        for frameID: UUID,
        in frames: [CutWorkspaceTrackingQueueFrame]
    ) -> CutWorkspaceTrackingQueueFrame? {
        frames.first(where: { $0.id == frameID })
    }

    private static func canAccept(
        _ item: CutWorkspaceTrackingQueueItemState,
        currentItem: TrackingQueueNavigatorItem?
    ) -> Bool {
        item.hasResolvedAssignment && currentItem?.isManualOverride == false
    }

    private static func canReassign(
        currentItem: TrackingQueueNavigatorItem?,
        selectedSubsetID: UUID?
    ) -> Bool {
        currentItem?.isManualOverride == false && selectedSubsetID != nil
    }

    private static func shortRegionLabel(_ regionID: UUID) -> String {
        String(regionID.uuidString.prefix(8))
    }
}
