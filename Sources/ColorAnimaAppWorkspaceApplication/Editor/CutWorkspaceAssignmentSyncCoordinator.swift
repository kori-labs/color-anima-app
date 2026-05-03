import Foundation

public struct AssignmentSyncAssignment: Hashable, Equatable, Sendable {
    public var groupID: UUID
    public var subsetID: UUID
    public var statusName: String
    public var highlightSplitDecision: SelectedRegionSplitDecision
    public var shadowSplitDecision: SelectedRegionSplitDecision

    public init(
        groupID: UUID,
        subsetID: UUID,
        statusName: String,
        highlightSplitDecision: SelectedRegionSplitDecision = .normal,
        shadowSplitDecision: SelectedRegionSplitDecision = .normal
    ) {
        self.groupID = groupID
        self.subsetID = subsetID
        self.statusName = statusName
        self.highlightSplitDecision = highlightSplitDecision
        self.shadowSplitDecision = shadowSplitDecision
    }
}

public struct AssignmentSyncRegionState: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var assignment: AssignmentSyncAssignment?

    public init(id: UUID = UUID(), assignment: AssignmentSyncAssignment? = nil) {
        self.id = id
        self.assignment = assignment
    }
}

public struct AssignmentSyncTrackingRecord: Hashable, Equatable, Sendable {
    public var targetRegionID: UUID
    public var reviewState: ConfidenceReviewState
    public var isManualCorrection: Bool
    public var assignedRegion: AssignmentSyncAssignment?

    public init(
        targetRegionID: UUID,
        reviewState: ConfidenceReviewState,
        isManualCorrection: Bool = false,
        assignedRegion: AssignmentSyncAssignment? = nil
    ) {
        self.targetRegionID = targetRegionID
        self.reviewState = reviewState
        self.isManualCorrection = isManualCorrection
        self.assignedRegion = assignedRegion
    }
}

public struct AssignmentSyncFrameState: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var regions: [AssignmentSyncRegionState]
    public var trackingRecords: [AssignmentSyncTrackingRecord]

    public init(
        id: UUID = UUID(),
        regions: [AssignmentSyncRegionState] = [],
        trackingRecords: [AssignmentSyncTrackingRecord] = []
    ) {
        self.id = id
        self.regions = regions
        self.trackingRecords = trackingRecords
    }
}

public struct AssignmentSyncPrototypeMember: Hashable, Equatable, Sendable {
    public var frameID: UUID
    public var regionID: UUID
    public var assignment: AssignmentSyncAssignment

    public init(frameID: UUID, regionID: UUID, assignment: AssignmentSyncAssignment) {
        self.frameID = frameID
        self.regionID = regionID
        self.assignment = assignment
    }
}

public struct AssignmentSyncPrototype: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID { subsetID }
    public var subsetID: UUID
    public var referenceMembers: [AssignmentSyncPrototypeMember]
    public var canonicalAssignment: AssignmentSyncAssignment?

    public init(
        subsetID: UUID,
        referenceMembers: [AssignmentSyncPrototypeMember] = [],
        canonicalAssignment: AssignmentSyncAssignment? = nil
    ) {
        self.subsetID = subsetID
        self.referenceMembers = referenceMembers
        self.canonicalAssignment = canonicalAssignment
    }

    public var canonicalStatusName: String? {
        canonicalAssignment?.statusName ?? referenceMembers.first?.assignment.statusName
    }
}

public struct AssignmentSyncCutState: Hashable, Equatable, Sendable {
    public var frames: [AssignmentSyncFrameState]
    public var prototypes: [AssignmentSyncPrototype]

    public init(
        frames: [AssignmentSyncFrameState] = [],
        prototypes: [AssignmentSyncPrototype] = []
    ) {
        self.frames = frames
        self.prototypes = prototypes
    }
}

public enum CutWorkspaceAssignmentSyncCoordinator {
    public struct RewriteResult: Hashable, Equatable, Sendable {
        public var updatedFrameIDs: [UUID]
        public var didRewritePrototypes: Bool

        public init(updatedFrameIDs: [UUID] = [], didRewritePrototypes: Bool = false) {
            self.updatedFrameIDs = updatedFrameIDs
            self.didRewritePrototypes = didRewritePrototypes
        }

        public var didRewriteAnything: Bool {
            didRewritePrototypes || updatedFrameIDs.isEmpty == false
        }
    }

    @discardableResult
    public static func rewriteStatusAcrossCut(
        inSubsetID subsetID: UUID,
        from oldStatusName: String,
        to newStatusName: String,
        in cutState: inout AssignmentSyncCutState
    ) -> RewriteResult {
        guard oldStatusName != newStatusName else {
            return RewriteResult()
        }

        var updatedFrameIDs: [UUID] = []

        for frameIndex in cutState.frames.indices {
            var didMutateFrame = false

            for regionIndex in cutState.frames[frameIndex].regions.indices {
                if rewriteAssignment(
                    &cutState.frames[frameIndex].regions[regionIndex].assignment,
                    inSubsetID: subsetID,
                    from: oldStatusName,
                    to: newStatusName
                ) {
                    didMutateFrame = true
                }
            }

            for recordIndex in cutState.frames[frameIndex].trackingRecords.indices {
                if rewriteAssignment(
                    &cutState.frames[frameIndex].trackingRecords[recordIndex].assignedRegion,
                    inSubsetID: subsetID,
                    from: oldStatusName,
                    to: newStatusName
                ) {
                    didMutateFrame = true
                }
            }

            if didMutateFrame {
                updatedFrameIDs.append(cutState.frames[frameIndex].id)
            }
        }

        let didRewritePrototypes = rewritePrototypes(
            &cutState.prototypes,
            inSubsetID: subsetID,
            from: oldStatusName,
            to: newStatusName
        )

        return RewriteResult(
            updatedFrameIDs: updatedFrameIDs,
            didRewritePrototypes: didRewritePrototypes
        )
    }

    private static func rewritePrototypes(
        _ prototypes: inout [AssignmentSyncPrototype],
        inSubsetID subsetID: UUID,
        from oldStatusName: String,
        to newStatusName: String
    ) -> Bool {
        var didMutate = false

        for prototypeIndex in prototypes.indices {
            var prototype = prototypes[prototypeIndex]
            guard prototype.subsetID == subsetID else {
                continue
            }

            for memberIndex in prototype.referenceMembers.indices {
                var member = prototype.referenceMembers[memberIndex]
                var assignment: AssignmentSyncAssignment? = member.assignment
                if rewriteAssignment(
                    &assignment,
                    inSubsetID: subsetID,
                    from: oldStatusName,
                    to: newStatusName
                ) {
                    member.assignment = assignment ?? member.assignment
                    prototype.referenceMembers[memberIndex] = member
                    didMutate = true
                }
            }

            if rewriteAssignment(
                &prototype.canonicalAssignment,
                inSubsetID: subsetID,
                from: oldStatusName,
                to: newStatusName
            ) {
                didMutate = true
            }

            prototypes[prototypeIndex] = prototype
        }

        return didMutate
    }

    private static func rewriteAssignment(
        _ assignment: inout AssignmentSyncAssignment?,
        inSubsetID subsetID: UUID,
        from oldStatusName: String,
        to newStatusName: String
    ) -> Bool {
        guard assignment?.subsetID == subsetID,
              assignment?.statusName == oldStatusName else {
            return false
        }

        assignment?.statusName = newStatusName
        return true
    }
}
