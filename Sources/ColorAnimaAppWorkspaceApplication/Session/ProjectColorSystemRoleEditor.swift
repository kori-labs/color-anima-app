import Foundation

enum ProjectColorSystemRoleEditor {
    @discardableResult
    static func updateSelectedPaletteRole(
        _ role: WritableKeyPath<ColorRoles, RGBAColor>,
        to rgba: RGBAColor,
        in state: inout ProjectColorSystemEditingState
    ) -> Bool {
        guard let selectedGroupIndex = ProjectColorSystemSelectionResolver.selectedGroupIndex(in: state),
              let selectedSubsetIndex = ProjectColorSystemSelectionResolver.selectedSubsetIndex(in: state, groupIndex: selectedGroupIndex),
              let selectedPaletteIndex = ProjectColorSystemSelectionResolver.selectedPaletteIndex(in: state, subsetIndex: selectedSubsetIndex)
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
        ProjectColorSystemRefreshDispatcher.applyColorSystemEditRefresh(
            scope: ProjectColorSystemRefreshDispatcher.refreshScope(for: role),
            editedSubsetID: editedSubsetID,
            in: &state
        )
        return true
    }

    @discardableResult
    static func updateSelectedSubsetFlag(
        _ keyPath: WritableKeyPath<ColorSystemSubset, Bool>,
        to newValue: Bool,
        in state: inout ProjectColorSystemEditingState
    ) -> Bool {
        guard let selectedGroupIndex = ProjectColorSystemSelectionResolver.selectedGroupIndex(in: state),
              let selectedSubsetIndex = ProjectColorSystemSelectionResolver.selectedSubsetIndex(in: state, groupIndex: selectedGroupIndex)
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
        ProjectColorSystemRefreshDispatcher.applyColorSystemEditRefresh(
            scope: ProjectColorSystemRefreshDispatcher.refreshScope(for: keyPath),
            editedSubsetID: editedSubsetID,
            in: &state
        )
        return true
    }
}
