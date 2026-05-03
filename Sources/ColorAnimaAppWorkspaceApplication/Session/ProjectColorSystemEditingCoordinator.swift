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

public enum ProjectColorSystemEditingCoordinator {
    @discardableResult
    public static func updateSelectedPaletteRole(
        _ role: WritableKeyPath<ColorRoles, RGBAColor>,
        to rgba: RGBAColor,
        in state: inout ProjectColorSystemEditingState
    ) -> Bool {
        guard let selectedGroupIndex = selectedGroupIndex(in: state),
              let selectedSubsetIndex = selectedSubsetIndex(in: state, groupIndex: selectedGroupIndex),
              let selectedPaletteIndex = selectedPaletteIndex(in: state, subsetIndex: selectedSubsetIndex)
        else {
            return false
        }

        let current = state.groups[selectedGroupIndex]
            .subsets[selectedSubsetIndex]
            .palettes[selectedPaletteIndex]
            .roles[keyPath: role]
        guard current != rgba else { return false }

        state.groups[selectedGroupIndex]
            .subsets[selectedSubsetIndex]
            .palettes[selectedPaletteIndex]
            .roles[keyPath: role] = rgba
        state.metadataDirty = true

        let editedSubsetID = state.groups[selectedGroupIndex]
            .subsets[selectedSubsetIndex].id
        applyColorSystemEditRefresh(
            scope: refreshScope(for: role),
            editedSubsetID: editedSubsetID,
            in: &state
        )
        return true
    }

    @discardableResult
    public static func updateSelectedSubsetFlag(
        _ keyPath: WritableKeyPath<ColorSystemSubset, Bool>,
        to newValue: Bool,
        in state: inout ProjectColorSystemEditingState
    ) -> Bool {
        guard let selectedGroupIndex = selectedGroupIndex(in: state),
              let selectedSubsetIndex = selectedSubsetIndex(in: state, groupIndex: selectedGroupIndex)
        else {
            return false
        }

        let current = state.groups[selectedGroupIndex]
            .subsets[selectedSubsetIndex][keyPath: keyPath]
        guard current != newValue else { return false }

        state.groups[selectedGroupIndex]
            .subsets[selectedSubsetIndex][keyPath: keyPath] = newValue
        state.metadataDirty = true

        let editedSubsetID = state.groups[selectedGroupIndex]
            .subsets[selectedSubsetIndex].id
        applyColorSystemEditRefresh(
            scope: refreshScope(for: keyPath),
            editedSubsetID: editedSubsetID,
            in: &state
        )
        return true
    }

    public static func renameGroup(
        _ groupID: UUID,
        to name: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false,
              let groupIndex = state.groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        var updatedGroups = state.groups
        guard updatedGroups[groupIndex].name != trimmedName else { return }
        updatedGroups[groupIndex].name = trimmedName
        applyColorSystemGroups(updatedGroups, in: &state)
    }

    public static func renameSubset(
        _ subsetID: UUID,
        to name: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false,
              let location = colorSystemSubsetLocation(for: subsetID, in: state.groups) else {
            return
        }

        var updatedGroups = state.groups
        guard updatedGroups[location.groupIndex].subsets[location.subsetIndex].name != trimmedName else {
            return
        }
        updatedGroups[location.groupIndex].subsets[location.subsetIndex].name = trimmedName
        applyColorSystemGroups(updatedGroups, in: &state)
    }

    @discardableResult
    public static func addGroup(in state: inout ProjectColorSystemEditingState) -> UUID {
        let newGroup = ColorSystemGroup(
            name: uniqueColorSystemName(prefix: "group", existing: state.groups.map(\.name)),
            subsets: [
                ColorSystemSubset(
                    name: "subset_1",
                    palettes: [StatusPalette(name: state.activeStatusName, roles: .neutral)]
                )
            ]
        )

        var updatedGroups = state.groups
        updatedGroups.append(newGroup)
        applyColorSystemGroups(updatedGroups, in: &state)
        selectGroup(newGroup.id, in: &state)
        return newGroup.id
    }

    public static func removeGroup(
        _ groupID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        guard let groupIndex = state.groups.firstIndex(where: { $0.id == groupID }) else { return }

        var updatedGroups = state.groups
        let removedGroup = updatedGroups.remove(at: groupIndex)
        state.groups = updatedGroups
        state.metadataDirty = true
        state.assignmentClearRequests.append(.group(removedGroup.id))

        if let selectedGroupID = state.selectedGroupID,
           let retainedGroupIndex = updatedGroups.firstIndex(where: { $0.id == selectedGroupID }) {
            let retainedGroup = updatedGroups[retainedGroupIndex]
            if let selectedSubsetID = state.selectedSubsetID,
               retainedGroup.subsets.contains(where: { $0.id == selectedSubsetID }) {
                // Keep current selection.
            } else {
                state.selectedSubsetID = retainedGroup.subsets.first?.id
            }
        } else if updatedGroups.isEmpty == false {
            let fallbackIndex = min(groupIndex, updatedGroups.count - 1)
            let fallbackGroup = updatedGroups[fallbackIndex]
            selectGroup(fallbackGroup.id, in: &state)
            state.selectedSubsetID = fallbackGroup.subsets.first?.id
        } else {
            state.selectedGroupID = nil
            state.selectedSubsetID = nil
        }

        normalizeColorSelection(in: &state)
        state.needsColorSystemRefresh = true
    }

    @discardableResult
    public static func addSubset(in state: inout ProjectColorSystemEditingState) -> UUID? {
        guard let selectedGroupIndex = selectedGroupIndex(in: state) else { return nil }
        let group = state.groups[selectedGroupIndex]
        let newSubset = ColorSystemSubset(
            name: uniqueColorSystemName(prefix: "subset", existing: group.subsets.map(\.name)),
            palettes: [StatusPalette(name: state.activeStatusName, roles: .neutral)]
        )

        var updatedGroups = state.groups
        updatedGroups[selectedGroupIndex].subsets.append(newSubset)
        applyColorSystemGroups(updatedGroups, in: &state)
        selectSubset(newSubset.id, in: &state)
        return newSubset.id
    }

    public static func removeSubset(
        _ subsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        guard let location = colorSystemSubsetLocation(for: subsetID, in: state.groups) else {
            return
        }

        var updatedGroups = state.groups
        let removedSubset = updatedGroups[location.groupIndex].subsets.remove(at: location.subsetIndex)
        state.groups = updatedGroups
        state.metadataDirty = true
        state.assignmentClearRequests.append(.subset(removedSubset.id))

        if state.selectedSubsetID == removedSubset.id {
            let fallbackSubsetID = updatedGroups[location.groupIndex].subsets.isEmpty
                ? nil
                : updatedGroups[location.groupIndex].subsets[
                    min(location.subsetIndex, updatedGroups[location.groupIndex].subsets.count - 1)
                ].id
            state.selectedSubsetID = fallbackSubsetID
        } else if let selectedGroupID = state.selectedGroupID,
                  let selectedGroup = updatedGroups.first(where: { $0.id == selectedGroupID }),
                  let selectedSubsetID = state.selectedSubsetID,
                  selectedGroup.subsets.contains(where: { $0.id == selectedSubsetID }) == false {
            state.selectedSubsetID = selectedGroup.subsets.first?.id
        }

        normalizeColorSelection(in: &state)
        state.needsColorSystemRefresh = true
    }

    public static func normalizeColorSelection(in state: inout ProjectColorSystemEditingState) {
        reconcileColorSelection(in: &state)
    }

    public static func selectGroup(
        _ groupID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        guard let groupIndex = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        state.selectedGroupID = groupID
        if let selectedSubsetID = state.selectedSubsetID,
           state.groups[groupIndex].subsets.contains(where: { $0.id == selectedSubsetID }) {
            syncActiveStatusWithSelection(in: &state)
            return
        }
        state.selectedSubsetID = state.groups[groupIndex].subsets.first?.id
        syncActiveStatusWithSelection(in: &state)
    }

    public static func selectSubset(
        _ subsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        guard let groupIndex = state.groups.firstIndex(where: { group in
            group.subsets.contains(where: { $0.id == subsetID })
        }) else {
            return
        }

        state.selectedGroupID = state.groups[groupIndex].id
        state.selectedSubsetID = subsetID
        syncActiveStatusWithSelection(in: &state)
    }

    public static func setActiveStatus(
        _ statusName: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        state.activeStatusName = statusName
        state.metadataDirty = true
    }

    public static func colorSystemSubsetLocation(
        for subsetID: UUID,
        in groups: [ColorSystemGroup]
    ) -> ProjectColorSystemSubsetLocation? {
        for groupIndex in groups.indices {
            if let subsetIndex = groups[groupIndex].subsets.firstIndex(where: { $0.id == subsetID }) {
                return ProjectColorSystemSubsetLocation(groupIndex: groupIndex, subsetIndex: subsetIndex)
            }
        }
        return nil
    }

    public static func refreshScope(
        for role: WritableKeyPath<ColorRoles, RGBAColor>
    ) -> ProjectColorSystemRefreshScope {
        if role == \.base {
            return .overlay
        }
        if role == \.highlight {
            return .highlightGuide
        }
        return .shadowGuide
    }

    public static func refreshScope(
        for keyPath: WritableKeyPath<ColorSystemSubset, Bool>
    ) -> ProjectColorSystemRefreshScope {
        keyPath == \.isHighlightEnabled ? .highlightGuide : .shadowGuide
    }

    public static func workspaceUsesEditedSubset(
        _ workspace: ProjectColorSystemWorkspaceUsageState,
        editedSubsetID: UUID
    ) -> Bool {
        workspace.subsetIDsByFrameID.values.contains { $0.contains(editedSubsetID) }
    }

    public static func affectedInactiveFrameIDsSplit(
        in workspace: ProjectColorSystemWorkspaceUsageState,
        editedSubsetID: UUID
    ) -> (adjacent: [UUID], rest: [UUID]) {
        let frames = workspace.frameIDsInDisplayOrder
        guard let selectedFrameID = workspace.selectedFrameID,
              let activeIndex = frames.firstIndex(of: selectedFrameID) else {
            return (adjacent: [], rest: [])
        }

        func containsEditedSubset(_ frameID: UUID) -> Bool {
            workspace.subsetIDsByFrameID[frameID]?.contains(editedSubsetID) == true
        }

        var adjacentIDs: [UUID] = []
        if activeIndex > 0 {
            let previous = frames[activeIndex - 1]
            if containsEditedSubset(previous) {
                adjacentIDs.append(previous)
            }
        }
        if activeIndex < frames.count - 1 {
            let next = frames[activeIndex + 1]
            if containsEditedSubset(next) {
                adjacentIDs.append(next)
            }
        }

        let adjacentSet = Set(adjacentIDs)
        let rest = frames.compactMap { frameID -> UUID? in
            guard frameID != selectedFrameID else { return nil }
            guard adjacentSet.contains(frameID) == false else { return nil }
            return containsEditedSubset(frameID) ? frameID : nil
        }

        return (adjacent: adjacentIDs, rest: rest)
    }

    private static func selectedGroupIndex(in state: ProjectColorSystemEditingState) -> Int? {
        guard let selectedGroupID = state.selectedGroupID else { return nil }
        return state.groups.firstIndex(where: { $0.id == selectedGroupID })
    }

    private static func selectedSubsetIndex(
        in state: ProjectColorSystemEditingState,
        groupIndex: Int
    ) -> Int? {
        guard let selectedSubsetID = state.selectedSubsetID else { return nil }
        return state.groups[groupIndex].subsets.firstIndex(where: { $0.id == selectedSubsetID })
    }

    private static func selectedPaletteIndex(
        in state: ProjectColorSystemEditingState,
        subsetIndex: Int
    ) -> Int? {
        guard let selectedGroupIndex = selectedGroupIndex(in: state) else { return nil }
        return state.groups[selectedGroupIndex].subsets[subsetIndex].palettes.firstIndex {
            $0.name == state.activeStatusName
        }
    }

    private static func selectedSubset(in state: ProjectColorSystemEditingState) -> ColorSystemSubset? {
        guard let selectedSubsetID = state.selectedSubsetID else { return nil }
        return state.groups.lazy
            .flatMap(\.subsets)
            .first(where: { $0.id == selectedSubsetID })
    }

    private static func reconcileColorSelection(in state: inout ProjectColorSystemEditingState) {
        if let selectedGroupID = state.selectedGroupID,
           state.groups.contains(where: { $0.id == selectedGroupID }) == false {
            state.selectedGroupID = nil
        }

        if state.selectedGroupID == nil {
            state.selectedGroupID = state.groups.first?.id
        }

        if let selectedGroupIndex = selectedGroupIndex(in: state) {
            let subsets = state.groups[selectedGroupIndex].subsets
            if let selectedSubsetID = state.selectedSubsetID,
               subsets.contains(where: { $0.id == selectedSubsetID }) == false {
                state.selectedSubsetID = nil
            }
            if state.selectedSubsetID == nil {
                state.selectedSubsetID = subsets.first?.id
            }
        } else {
            state.selectedSubsetID = nil
        }

        syncActiveStatusWithSelection(in: &state)
    }

    private static func syncActiveStatusWithSelection(in state: inout ProjectColorSystemEditingState) {
        guard let selectedSubset = selectedSubset(in: state) else {
            state.activeStatusName = "default"
            return
        }

        if selectedSubset.palettes.contains(where: { $0.name == state.activeStatusName }) {
            return
        }

        state.activeStatusName = selectedSubset.palettes.first?.name ?? "default"
    }

    private static func applyColorSystemEditRefresh(
        scope: ProjectColorSystemRefreshScope,
        editedSubsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        let inactiveCutIDs = state.workspaces.keys
            .filter { $0 != state.activeCutID }
            .sorted { $0.uuidString < $1.uuidString }
            .filter { cutID in
                guard let workspace = state.workspaces[cutID] else { return false }
                return workspaceUsesEditedSubset(workspace, editedSubsetID: editedSubsetID)
            }

        let split: (adjacent: [UUID], rest: [UUID])
        if let activeCutID = state.activeCutID,
           let workspace = state.workspaces[activeCutID] {
            split = affectedInactiveFrameIDsSplit(in: workspace, editedSubsetID: editedSubsetID)
        } else {
            split = (adjacent: [], rest: [])
        }

        state.needsColorSystemRefresh = true
        state.refreshRequests.append(
            ProjectColorSystemEditRefreshRequest(
                scope: scope,
                editedSubsetID: editedSubsetID,
                activeCutID: state.activeCutID,
                inactiveCutIDs: inactiveCutIDs,
                prewarmAdjacentFrameIDs: split.adjacent,
                prewarmRestFrameIDs: split.rest
            )
        )
    }

    private static func uniqueColorSystemName(prefix: String, existing: [String]) -> String {
        var counter = 1
        var candidate = "\(prefix)_\(counter)"
        while existing.contains(candidate) {
            counter += 1
            candidate = "\(prefix)_\(counter)"
        }
        return candidate
    }

    private static func applyColorSystemGroups(
        _ updatedGroups: [ColorSystemGroup],
        in state: inout ProjectColorSystemEditingState
    ) {
        guard state.groups != updatedGroups else { return }
        state.groups = updatedGroups
        state.metadataDirty = true
        reconcileColorSelection(in: &state)
        state.needsColorSystemRefresh = true
    }
}
