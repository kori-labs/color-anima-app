import Foundation

public struct ProjectAssignmentSyncRequest: Hashable, Equatable, Sendable {
    public var subsetID: UUID
    public var oldStatusName: String
    public var newStatusName: String

    public init(subsetID: UUID, oldStatusName: String, newStatusName: String) {
        self.subsetID = subsetID
        self.oldStatusName = oldStatusName
        self.newStatusName = newStatusName
    }
}

public struct ProjectStatusEditingState: Hashable, Equatable, Sendable {
    public var groups: [ColorSystemGroup]
    public var selectedSubsetID: UUID?
    public var activeStatusName: String
    public var metadataDirty: Bool
    public var needsColorSystemRefresh: Bool
    public var rewriteRequests: [ProjectAssignmentSyncRequest]

    public init(
        groups: [ColorSystemGroup] = [],
        selectedSubsetID: UUID? = nil,
        activeStatusName: String = "default",
        metadataDirty: Bool = false,
        needsColorSystemRefresh: Bool = false,
        rewriteRequests: [ProjectAssignmentSyncRequest] = []
    ) {
        self.groups = groups
        self.selectedSubsetID = selectedSubsetID
        self.activeStatusName = activeStatusName
        self.metadataDirty = metadataDirty
        self.needsColorSystemRefresh = needsColorSystemRefresh
        self.rewriteRequests = rewriteRequests
    }
}

public enum ProjectStatusEditingCoordinator {
    @discardableResult
    public static func addStatus(
        to subsetID: UUID,
        suggestedName: String? = nil,
        in state: inout ProjectStatusEditingState
    ) -> String? {
        guard let location = colorSystemSubsetLocation(for: subsetID, in: state.groups) else {
            return nil
        }

        let subset = state.groups[location.groupIndex].subsets[location.subsetIndex]
        let existingNames = subset.palettes.map(\.name)
        let sourcePalette = sourcePaletteForStatusEditing(in: subset, state: state)
        let newName = uniqueStatusName(suggestedName: suggestedName, existing: existingNames)

        state.groups[location.groupIndex]
            .subsets[location.subsetIndex]
            .palettes
            .append(StatusPalette(name: newName, roles: sourcePalette.roles))

        state.metadataDirty = true
        if state.selectedSubsetID == subsetID {
            setActiveStatus(newName, in: &state)
        }
        syncActiveStatusWithSelection(in: &state)
        state.needsColorSystemRefresh = true

        return newName
    }

    @discardableResult
    public static func renameStatus(
        in subsetID: UUID,
        from oldName: String,
        to newName: String,
        in state: inout ProjectStatusEditingState
    ) -> Bool {
        guard let location = colorSystemSubsetLocation(for: subsetID, in: state.groups),
              let normalizedName = normalizedStatusName(newName) else {
            return false
        }

        var palettes = state.groups[location.groupIndex].subsets[location.subsetIndex].palettes
        guard let paletteIndex = palettes.firstIndex(where: { $0.name == oldName }) else {
            return false
        }
        guard oldName != normalizedName else { return false }
        guard palettes.contains(where: { $0.name == normalizedName }) == false else { return false }

        palettes[paletteIndex].name = normalizedName
        state.groups[location.groupIndex].subsets[location.subsetIndex].palettes = palettes
        state.metadataDirty = true

        if state.selectedSubsetID == subsetID,
           state.activeStatusName == oldName {
            setActiveStatus(normalizedName, in: &state)
        }

        appendRewriteRequest(
            subsetID: subsetID,
            from: oldName,
            to: normalizedName,
            in: &state
        )
        syncActiveStatusWithSelection(in: &state)
        state.needsColorSystemRefresh = true

        return true
    }

    @discardableResult
    public static func removeStatus(
        in subsetID: UUID,
        named statusName: String,
        fallbackStatusName: String,
        in state: inout ProjectStatusEditingState
    ) -> Bool {
        guard let location = colorSystemSubsetLocation(for: subsetID, in: state.groups),
              let normalizedFallbackStatusName = normalizedStatusName(fallbackStatusName) else {
            return false
        }

        var palettes = state.groups[location.groupIndex].subsets[location.subsetIndex].palettes
        guard palettes.count > 1 else { return false }
        guard let paletteIndex = palettes.firstIndex(where: { $0.name == statusName }) else {
            return false
        }
        guard normalizedFallbackStatusName != statusName else { return false }
        guard palettes.contains(where: { $0.name == normalizedFallbackStatusName }) else {
            return false
        }

        palettes.remove(at: paletteIndex)
        state.groups[location.groupIndex].subsets[location.subsetIndex].palettes = palettes
        state.metadataDirty = true

        if state.selectedSubsetID == subsetID,
           state.activeStatusName == statusName {
            setActiveStatus(normalizedFallbackStatusName, in: &state)
        }

        appendRewriteRequest(
            subsetID: subsetID,
            from: statusName,
            to: normalizedFallbackStatusName,
            in: &state
        )
        syncActiveStatusWithSelection(in: &state)
        state.needsColorSystemRefresh = true

        return true
    }

    public static func normalizedStatusName(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    public static func uniqueStatusName(suggestedName: String?, existing: [String]) -> String {
        if let normalizedName = normalizedStatusName(suggestedName),
           existing.contains(normalizedName) == false {
            return normalizedName
        }
        return nextStatusName(existing: existing)
    }

    private struct ColorSystemSubsetLocation {
        var groupIndex: Int
        var subsetIndex: Int
    }

    private static func colorSystemSubsetLocation(
        for subsetID: UUID,
        in groups: [ColorSystemGroup]
    ) -> ColorSystemSubsetLocation? {
        for groupIndex in groups.indices {
            if let subsetIndex = groups[groupIndex].subsets.firstIndex(where: { $0.id == subsetID }) {
                return ColorSystemSubsetLocation(groupIndex: groupIndex, subsetIndex: subsetIndex)
            }
        }
        return nil
    }

    private static func sourcePaletteForStatusEditing(
        in subset: ColorSystemSubset,
        state: ProjectStatusEditingState
    ) -> StatusPalette {
        if state.selectedSubsetID == subset.id,
           let activePalette = subset.palettes.first(where: { $0.name == state.activeStatusName }) {
            return activePalette
        }

        return subset.palettes.first ?? StatusPalette(name: "default", roles: .neutral)
    }

    private static func nextStatusName(existing: [String]) -> String {
        var index = 2
        var candidate = "status_\(index)"
        while existing.contains(candidate) {
            index += 1
            candidate = "status_\(index)"
        }
        return candidate
    }

    private static func setActiveStatus(
        _ statusName: String,
        in state: inout ProjectStatusEditingState
    ) {
        state.activeStatusName = statusName
        state.metadataDirty = true
    }

    private static func syncActiveStatusWithSelection(
        in state: inout ProjectStatusEditingState
    ) {
        guard let selectedSubset = selectedSubset(in: state) else {
            state.activeStatusName = "default"
            return
        }

        if selectedSubset.palettes.contains(where: { $0.name == state.activeStatusName }) {
            return
        }

        state.activeStatusName = selectedSubset.palettes.first?.name ?? "default"
    }

    private static func selectedSubset(in state: ProjectStatusEditingState) -> ColorSystemSubset? {
        guard let selectedSubsetID = state.selectedSubsetID else { return nil }
        return state.groups.lazy
            .flatMap(\.subsets)
            .first(where: { $0.id == selectedSubsetID })
    }

    private static func appendRewriteRequest(
        subsetID: UUID,
        from oldStatusName: String,
        to newStatusName: String,
        in state: inout ProjectStatusEditingState
    ) {
        guard oldStatusName != newStatusName else { return }
        state.rewriteRequests.append(
            ProjectAssignmentSyncRequest(
                subsetID: subsetID,
                oldStatusName: oldStatusName,
                newStatusName: newStatusName
            )
        )
    }
}
