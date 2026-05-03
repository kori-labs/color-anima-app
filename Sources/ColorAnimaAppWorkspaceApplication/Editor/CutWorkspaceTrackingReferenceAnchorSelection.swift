import Foundation

public struct TrackingReferenceAnchorSelection: Hashable, Equatable, Sendable {
    public var anchorFrameIDs: [UUID]
    public var preferredFrameID: UUID?

    public init(anchorFrameIDs: [UUID], preferredFrameID: UUID?) {
        self.anchorFrameIDs = anchorFrameIDs
        self.preferredFrameID = preferredFrameID
    }
}

public enum CutWorkspaceTrackingReferenceAnchorSelection {
    public static func makeReferenceAnchorSelection(
        frameOrder: [UUID],
        keyFrameIDs: [UUID],
        selectedFrameSelectionAnchorID: UUID? = nil,
        activeReferenceFrameID: UUID? = nil,
        selectedFrameID: UUID? = nil
    ) -> TrackingReferenceAnchorSelection {
        let referenceFrameIDSet = Set(keyFrameIDs)
        let anchorFrameIDs = frameOrder.filter { referenceFrameIDSet.contains($0) }
        let preferredFrameID = preferredReferenceAnchorFrameID(
            anchorFrameIDs: anchorFrameIDs,
            selectedFrameSelectionAnchorID: selectedFrameSelectionAnchorID,
            activeReferenceFrameID: activeReferenceFrameID,
            selectedFrameID: selectedFrameID
        )
        return TrackingReferenceAnchorSelection(
            anchorFrameIDs: anchorFrameIDs,
            preferredFrameID: preferredFrameID
        )
    }

    private static func preferredReferenceAnchorFrameID(
        anchorFrameIDs: [UUID],
        selectedFrameSelectionAnchorID: UUID?,
        activeReferenceFrameID: UUID?,
        selectedFrameID: UUID?
    ) -> UUID? {
        guard anchorFrameIDs.isEmpty == false else { return nil }
        let anchorFrameIDSet = Set(anchorFrameIDs)

        if let selectedFrameSelectionAnchorID,
           anchorFrameIDSet.contains(selectedFrameSelectionAnchorID) {
            return selectedFrameSelectionAnchorID
        }

        if let activeReferenceFrameID,
           anchorFrameIDSet.contains(activeReferenceFrameID) {
            return activeReferenceFrameID
        }

        if let selectedFrameID,
           anchorFrameIDSet.contains(selectedFrameID) {
            return selectedFrameID
        }

        return anchorFrameIDs.first
    }
}
