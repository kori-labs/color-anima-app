import Foundation

public enum ProjectColorSystemAssignmentClearRequest: Hashable, Equatable, Sendable {
    case group(UUID)
    case subset(UUID)
}

public enum ProjectColorSystemRefreshScope: Hashable, Equatable, Sendable {
    case overlay
    case highlightGuide
    case shadowGuide
}

public struct ProjectColorSystemWorkspaceUsageState: Hashable, Equatable, Sendable {
    public var selectedFrameID: UUID?
    public var frameIDsInDisplayOrder: [UUID]
    public var subsetIDsByFrameID: [UUID: Set<UUID>]

    public init(
        selectedFrameID: UUID? = nil,
        frameIDsInDisplayOrder: [UUID] = [],
        subsetIDsByFrameID: [UUID: Set<UUID>] = [:]
    ) {
        self.selectedFrameID = selectedFrameID
        self.frameIDsInDisplayOrder = frameIDsInDisplayOrder
        self.subsetIDsByFrameID = subsetIDsByFrameID
    }
}

public struct ProjectColorSystemEditRefreshRequest: Hashable, Equatable, Sendable {
    public var scope: ProjectColorSystemRefreshScope
    public var editedSubsetID: UUID
    public var activeCutID: UUID?
    public var inactiveCutIDs: [UUID]
    public var prewarmAdjacentFrameIDs: [UUID]
    public var prewarmRestFrameIDs: [UUID]

    public init(
        scope: ProjectColorSystemRefreshScope,
        editedSubsetID: UUID,
        activeCutID: UUID? = nil,
        inactiveCutIDs: [UUID] = [],
        prewarmAdjacentFrameIDs: [UUID] = [],
        prewarmRestFrameIDs: [UUID] = []
    ) {
        self.scope = scope
        self.editedSubsetID = editedSubsetID
        self.activeCutID = activeCutID
        self.inactiveCutIDs = inactiveCutIDs
        self.prewarmAdjacentFrameIDs = prewarmAdjacentFrameIDs
        self.prewarmRestFrameIDs = prewarmRestFrameIDs
    }
}

public struct ProjectColorSystemSubsetLocation: Hashable, Equatable, Sendable {
    public var groupIndex: Int
    public var subsetIndex: Int

    public init(groupIndex: Int, subsetIndex: Int) {
        self.groupIndex = groupIndex
        self.subsetIndex = subsetIndex
    }
}

public struct ProjectColorSystemEditingState: Hashable, Equatable, Sendable {
    public var groups: [ColorSystemGroup]
    public var selectedGroupID: UUID?
    public var selectedSubsetID: UUID?
    public var activeStatusName: String
    public var metadataDirty: Bool
    public var needsColorSystemRefresh: Bool
    public var assignmentClearRequests: [ProjectColorSystemAssignmentClearRequest]
    public var activeCutID: UUID?
    public var workspaces: [UUID: ProjectColorSystemWorkspaceUsageState]
    public var refreshRequests: [ProjectColorSystemEditRefreshRequest]

    public init(
        groups: [ColorSystemGroup] = [],
        selectedGroupID: UUID? = nil,
        selectedSubsetID: UUID? = nil,
        activeStatusName: String = "default",
        metadataDirty: Bool = false,
        needsColorSystemRefresh: Bool = false,
        assignmentClearRequests: [ProjectColorSystemAssignmentClearRequest] = [],
        activeCutID: UUID? = nil,
        workspaces: [UUID: ProjectColorSystemWorkspaceUsageState] = [:],
        refreshRequests: [ProjectColorSystemEditRefreshRequest] = []
    ) {
        self.groups = groups
        self.selectedGroupID = selectedGroupID
        self.selectedSubsetID = selectedSubsetID
        self.activeStatusName = activeStatusName
        self.metadataDirty = metadataDirty
        self.needsColorSystemRefresh = needsColorSystemRefresh
        self.assignmentClearRequests = assignmentClearRequests
        self.activeCutID = activeCutID
        self.workspaces = workspaces
        self.refreshRequests = refreshRequests
    }
}
