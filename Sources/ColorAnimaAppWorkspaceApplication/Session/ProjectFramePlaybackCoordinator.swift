import Foundation

public struct ProjectFramePlaybackWorkspaceState: Hashable, Equatable, Sendable {
    public var frameSelection: CutWorkspaceFrameSelectionState
    public var isFramePlaybackActive: Bool
    public var frameIDsRequiringAssetLoad: Set<UUID>
    public var errorMessage: String?

    public init(
        frameSelection: CutWorkspaceFrameSelectionState = CutWorkspaceFrameSelectionState(),
        isFramePlaybackActive: Bool = false,
        frameIDsRequiringAssetLoad: Set<UUID> = [],
        errorMessage: String? = nil
    ) {
        self.frameSelection = frameSelection
        self.isFramePlaybackActive = isFramePlaybackActive
        self.frameIDsRequiringAssetLoad = frameIDsRequiringAssetLoad
        self.errorMessage = errorMessage
    }
}

public struct ProjectFramePlaybackState: Hashable, Equatable, Sendable {
    public var activeCutID: UUID?
    public var framePlaybackCutID: UUID?
    public var projectPlaybackFPS: Int
    public var workspaces: [UUID: ProjectFramePlaybackWorkspaceState]
    public var needsActiveCutRefresh: Bool
    public var pendingAssetLoadCutIDs: [UUID]
    public var pendingPrefetchRequests: [ProjectFramePlaybackPrefetchRequest]

    public init(
        activeCutID: UUID? = nil,
        framePlaybackCutID: UUID? = nil,
        projectPlaybackFPS: Int = 12,
        workspaces: [UUID: ProjectFramePlaybackWorkspaceState] = [:],
        needsActiveCutRefresh: Bool = false,
        pendingAssetLoadCutIDs: [UUID] = [],
        pendingPrefetchRequests: [ProjectFramePlaybackPrefetchRequest] = []
    ) {
        self.activeCutID = activeCutID
        self.framePlaybackCutID = framePlaybackCutID
        self.projectPlaybackFPS = projectPlaybackFPS
        self.workspaces = workspaces
        self.needsActiveCutRefresh = needsActiveCutRefresh
        self.pendingAssetLoadCutIDs = pendingAssetLoadCutIDs
        self.pendingPrefetchRequests = pendingPrefetchRequests
    }
}

public struct ProjectFramePlaybackPrefetchRequest: Hashable, Equatable, Sendable {
    public var cutID: UUID
    public var selectedFrameID: UUID

    public init(cutID: UUID, selectedFrameID: UUID) {
        self.cutID = cutID
        self.selectedFrameID = selectedFrameID
    }
}

public enum ProjectFramePlaybackToggleResult: Hashable, Equatable, Sendable {
    case ignored
    case started(cutID: UUID, frameDurationNanoseconds: UInt64)
    case stopped(cutID: UUID?)
}

public struct ProjectFramePlaybackAdvanceResult: Hashable, Equatable, Sendable {
    public var cutID: UUID
    public var selectedFrameID: UUID?
    public var selectionOutcome: CutWorkspaceFrameSelectionOutcome?
    public var needsAssetLoad: Bool
    public var stoppedPlayback: Bool

    public init(
        cutID: UUID,
        selectedFrameID: UUID?,
        selectionOutcome: CutWorkspaceFrameSelectionOutcome?,
        needsAssetLoad: Bool,
        stoppedPlayback: Bool
    ) {
        self.cutID = cutID
        self.selectedFrameID = selectedFrameID
        self.selectionOutcome = selectionOutcome
        self.needsAssetLoad = needsAssetLoad
        self.stoppedPlayback = stoppedPlayback
    }
}

public enum ProjectFramePlaybackCoordinator {
    @discardableResult
    public static func toggleFramePlayback(
        in state: inout ProjectFramePlaybackState
    ) -> ProjectFramePlaybackToggleResult {
        guard let activeCutID = state.activeCutID,
              let workspace = state.workspaces[activeCutID] else {
            return .ignored
        }

        if workspace.isFramePlaybackActive {
            let stoppedCutID = stopFramePlayback(in: &state)
            state.needsActiveCutRefresh = true
            return .stopped(cutID: stoppedCutID)
        }

        return startFramePlayback(for: activeCutID, in: &state)
    }

    @discardableResult
    public static func stopFramePlayback(
        in state: inout ProjectFramePlaybackState
    ) -> UUID? {
        let stoppedCutID = state.framePlaybackCutID
        if let stoppedCutID,
           var workspace = state.workspaces[stoppedCutID] {
            workspace.isFramePlaybackActive = false
            state.workspaces[stoppedCutID] = workspace
        }
        state.framePlaybackCutID = nil
        return stoppedCutID
    }

    @discardableResult
    public static func restartFramePlaybackIfNeeded(
        in state: inout ProjectFramePlaybackState
    ) -> ProjectFramePlaybackToggleResult {
        guard let cutID = state.framePlaybackCutID,
              let workspace = state.workspaces[cutID],
              workspace.isFramePlaybackActive else {
            return .ignored
        }

        return startFramePlayback(for: cutID, in: &state)
    }

    @discardableResult
    public static func startFramePlayback(
        for cutID: UUID,
        in state: inout ProjectFramePlaybackState
    ) -> ProjectFramePlaybackToggleResult {
        guard state.activeCutID == cutID,
              var workspace = state.workspaces[cutID] else {
            return .ignored
        }

        CutWorkspaceFrameSelectionCoordinator.collapseSelectionToPrimaryFrame(
            in: &workspace.frameSelection
        )
        workspace.isFramePlaybackActive = true
        state.workspaces[cutID] = workspace
        state.framePlaybackCutID = cutID
        state.needsActiveCutRefresh = true

        return .started(
            cutID: cutID,
            frameDurationNanoseconds: ProjectPlaybackTiming.frameDurationNanoseconds(
                for: state.projectPlaybackFPS
            )
        )
    }

    @discardableResult
    public static func advanceFramePlayback(
        for cutID: UUID,
        in state: inout ProjectFramePlaybackState
    ) -> ProjectFramePlaybackAdvanceResult {
        guard state.framePlaybackCutID == cutID,
              state.activeCutID == cutID,
              var workspace = state.workspaces[cutID],
              workspace.isFramePlaybackActive else {
            stopFramePlayback(in: &state)
            state.needsActiveCutRefresh = true
            return ProjectFramePlaybackAdvanceResult(
                cutID: cutID,
                selectedFrameID: nil,
                selectionOutcome: nil,
                needsAssetLoad: false,
                stoppedPlayback: true
            )
        }

        let selectionOutcome = CutWorkspaceFrameSelectionCoordinator.advancePlaybackFrame(
            in: &workspace.frameSelection
        )
        let selectedFrameID = workspace.frameSelection.selectedFrameID
        let needsAssetLoad = selectedFrameID.map {
            workspace.frameIDsRequiringAssetLoad.contains($0)
        } ?? false

        if needsAssetLoad {
            appendUnique(cutID, to: &state.pendingAssetLoadCutIDs)
        }
        if let selectedFrameID {
            appendUnique(
                ProjectFramePlaybackPrefetchRequest(
                    cutID: cutID,
                    selectedFrameID: selectedFrameID
                ),
                to: &state.pendingPrefetchRequests
            )
        }

        state.workspaces[cutID] = workspace
        state.needsActiveCutRefresh = true

        return ProjectFramePlaybackAdvanceResult(
            cutID: cutID,
            selectedFrameID: selectedFrameID,
            selectionOutcome: selectionOutcome,
            needsAssetLoad: needsAssetLoad,
            stoppedPlayback: false
        )
    }

    public static func completeAssetLoad(
        for cutID: UUID,
        loadedFrameID: UUID? = nil,
        errorMessage: String? = nil,
        in state: inout ProjectFramePlaybackState
    ) {
        state.pendingAssetLoadCutIDs.removeAll { $0 == cutID }
        guard var workspace = state.workspaces[cutID] else { return }
        if let loadedFrameID {
            workspace.frameIDsRequiringAssetLoad.remove(loadedFrameID)
        }
        workspace.errorMessage = errorMessage
        state.workspaces[cutID] = workspace
    }

    private static func appendUnique<T: Equatable>(_ value: T, to values: inout [T]) {
        guard values.contains(value) == false else { return }
        values.append(value)
    }
}
