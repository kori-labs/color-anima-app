import Foundation

public struct WorkspaceSelectionModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let additive = WorkspaceSelectionModifiers(rawValue: 1 << 0)
    public static let range = WorkspaceSelectionModifiers(rawValue: 1 << 1)
}

public enum WorkspaceDropPosition: String, Hashable, Sendable {
    case before
    case after
    case append
}

public typealias ProjectTreeDropPosition = WorkspaceDropPosition

public struct WorkspaceTreeDropTarget: Hashable, Sendable {
    public var targetNodeID: UUID
    public var position: WorkspaceDropPosition

    public init(targetNodeID: UUID, position: WorkspaceDropPosition) {
        self.targetNodeID = targetNodeID
        self.position = position
    }
}

public struct WorkspaceFrameDropTarget: Hashable, Sendable {
    public var targetFrameID: UUID?
    public var position: WorkspaceDropPosition

    public init(targetFrameID: UUID?, position: WorkspaceDropPosition) {
        self.targetFrameID = targetFrameID
        self.position = position
    }
}

public enum WorkspaceProjectTreeNodeKind: String, Hashable, Sendable {
    case project
    case sequence
    case scene
    case cut
}

public struct WorkspaceProjectTreeNode: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: WorkspaceProjectTreeNodeKind
    public var name: String
    public var children: [WorkspaceProjectTreeNode]

    public init(
        id: UUID,
        kind: WorkspaceProjectTreeNodeKind,
        name: String,
        children: [WorkspaceProjectTreeNode] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.children = children
    }
}

public struct WorkspacePendingCloseRequest: Equatable, Sendable {
    public var dirtyCutIDs: [UUID]

    public init(dirtyCutIDs: [UUID]) {
        self.dirtyCutIDs = dirtyCutIDs
    }
}
