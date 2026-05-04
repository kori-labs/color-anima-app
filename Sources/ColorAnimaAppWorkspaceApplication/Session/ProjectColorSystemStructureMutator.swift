import Foundation

enum ProjectColorSystemStructureMutator {
    static func renameGroup(
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

    static func renameSubset(
        _ subsetID: UUID,
        to name: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false,
              let location = ProjectColorSystemSelectionResolver.colorSystemSubsetLocation(for: subsetID, in: state.groups) else {
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
    static func addGroup(in state: inout ProjectColorSystemEditingState) -> UUID {
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
        ProjectColorSystemSelectionResolver.selectGroup(newGroup.id, in: &state)
        return newGroup.id
    }

    static func removeGroup(
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
            ProjectColorSystemSelectionResolver.selectGroup(fallbackGroup.id, in: &state)
            state.selectedSubsetID = fallbackGroup.subsets.first?.id
        } else {
            state.selectedGroupID = nil
            state.selectedSubsetID = nil
        }

        ProjectColorSystemSelectionResolver.normalizeColorSelection(in: &state)
        state.needsColorSystemRefresh = true
    }

    @discardableResult
    static func addSubset(in state: inout ProjectColorSystemEditingState) -> UUID? {
        guard let selectedGroupIndex = ProjectColorSystemSelectionResolver.selectedGroupIndex(in: state) else { return nil }
        let group = state.groups[selectedGroupIndex]
        let newSubset = ColorSystemSubset(
            name: uniqueColorSystemName(prefix: "subset", existing: group.subsets.map(\.name)),
            palettes: [StatusPalette(name: state.activeStatusName, roles: .neutral)]
        )

        var updatedGroups = state.groups
        updatedGroups[selectedGroupIndex].subsets.append(newSubset)
        applyColorSystemGroups(updatedGroups, in: &state)
        ProjectColorSystemSelectionResolver.selectSubset(newSubset.id, in: &state)
        return newSubset.id
    }

    static func removeSubset(
        _ subsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        guard let location = ProjectColorSystemSelectionResolver.colorSystemSubsetLocation(for: subsetID, in: state.groups) else {
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

        ProjectColorSystemSelectionResolver.normalizeColorSelection(in: &state)
        state.needsColorSystemRefresh = true
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
        ProjectColorSystemSelectionResolver.normalizeColorSelection(in: &state)
        state.needsColorSystemRefresh = true
    }
}
