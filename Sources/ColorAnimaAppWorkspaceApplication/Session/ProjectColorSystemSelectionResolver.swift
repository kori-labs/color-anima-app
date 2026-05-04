import Foundation

enum ProjectColorSystemSelectionResolver {
    static func normalizeColorSelection(in state: inout ProjectColorSystemEditingState) {
        reconcileColorSelection(in: &state)
    }

    static func selectGroup(
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

    static func selectSubset(
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

    static func setActiveStatus(
        _ statusName: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        state.activeStatusName = statusName
        state.metadataDirty = true
    }

    static func colorSystemSubsetLocation(
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

    static func selectedGroupIndex(in state: ProjectColorSystemEditingState) -> Int? {
        guard let selectedGroupID = state.selectedGroupID else { return nil }
        return state.groups.firstIndex(where: { $0.id == selectedGroupID })
    }

    static func selectedSubsetIndex(
        in state: ProjectColorSystemEditingState,
        groupIndex: Int
    ) -> Int? {
        guard let selectedSubsetID = state.selectedSubsetID else { return nil }
        return state.groups[groupIndex].subsets.firstIndex(where: { $0.id == selectedSubsetID })
    }

    static func selectedPaletteIndex(
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
}
