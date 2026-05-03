import Foundation

public struct TrackingRunReadiness: Hashable, Equatable, Sendable {
    public var canRun: Bool
    public var reason: String?

    public init(canRun: Bool, reason: String? = nil) {
        self.canRun = canRun
        self.reason = reason
    }
}

public struct CutWorkspaceTrackingReadinessFrame: Hashable, Equatable, Sendable {
    public var id: UUID
    public var hasExtractedRegions: Bool
    public var hasAssignedRegions: Bool

    public init(
        id: UUID,
        hasExtractedRegions: Bool,
        hasAssignedRegions: Bool
    ) {
        self.id = id
        self.hasExtractedRegions = hasExtractedRegions
        self.hasAssignedRegions = hasAssignedRegions
    }
}

public enum CutWorkspaceTrackingReadiness {
    public struct EffectiveReferenceSelection: Hashable, Equatable, Sendable {
        public let effectiveReferenceFrameIDs: [UUID]
        public let effectivePreferredReferenceFrameID: UUID?

        public init(
            effectiveReferenceFrameIDs: [UUID],
            effectivePreferredReferenceFrameID: UUID?
        ) {
            self.effectiveReferenceFrameIDs = effectiveReferenceFrameIDs
            self.effectivePreferredReferenceFrameID = effectivePreferredReferenceFrameID
        }
    }

    public static func readiness(
        frames: [CutWorkspaceTrackingReadinessFrame],
        keyFrameIDs: [UUID],
        isTrackingTaskActive: Bool = false
    ) -> TrackingRunReadiness {
        if isTrackingTaskActive {
            return TrackingRunReadiness(canRun: false, reason: "A tracking task is already in progress.")
        }

        guard frames.count >= 2 else {
            return TrackingRunReadiness(canRun: false, reason: "Tracking needs at least 2 frames.")
        }

        guard keyFrameIDs.isEmpty == false else {
            return TrackingRunReadiness(canRun: false, reason: "Add a reference frame before running tracking.")
        }

        guard frames.allSatisfy(\.hasExtractedRegions) else {
            return TrackingRunReadiness(
                canRun: false,
                reason: "Extract regions for every frame before running tracking."
            )
        }

        let referenceFrameSet = Set(keyFrameIDs)
        let targetFrameCount = frames.filter { referenceFrameSet.contains($0.id) == false }.count
        guard targetFrameCount > 0 else {
            return TrackingRunReadiness(
                canRun: false,
                reason: "At least one non-reference frame is required for tracking."
            )
        }

        return TrackingRunReadiness(canRun: true)
    }

    public static func demoteReferenceFrameIDs(
        referenceIDs: [UUID],
        preferredID: UUID?,
        frames: [CutWorkspaceTrackingReadinessFrame]
    ) -> EffectiveReferenceSelection {
        let effectiveRefIDs = referenceIDs.filter { frameID in
            frames.first(where: { $0.id == frameID })?.hasAssignedRegions == true
        }
        let effectiveRefIDSet = Set(effectiveRefIDs)
        let effectivePreferredRefID = preferredID.flatMap {
            effectiveRefIDSet.contains($0) ? $0 : nil
        }
        return EffectiveReferenceSelection(
            effectiveReferenceFrameIDs: effectiveRefIDs,
            effectivePreferredReferenceFrameID: effectivePreferredRefID
        )
    }
}
