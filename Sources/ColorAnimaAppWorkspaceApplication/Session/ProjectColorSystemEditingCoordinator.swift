import Foundation

public enum ProjectColorSystemEditingCoordinator {
    @discardableResult
    public static func updateSelectedPaletteRole(
        _ role: WritableKeyPath<ColorRoles, RGBAColor>,
        to rgba: RGBAColor,
        in state: inout ProjectColorSystemEditingState
    ) -> Bool {
        ProjectColorSystemRoleEditor.updateSelectedPaletteRole(role, to: rgba, in: &state)
    }

    @discardableResult
    public static func updateSelectedSubsetFlag(
        _ keyPath: WritableKeyPath<ColorSystemSubset, Bool>,
        to newValue: Bool,
        in state: inout ProjectColorSystemEditingState
    ) -> Bool {
        ProjectColorSystemRoleEditor.updateSelectedSubsetFlag(keyPath, to: newValue, in: &state)
    }

    public static func renameGroup(
        _ groupID: UUID,
        to name: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemStructureMutator.renameGroup(groupID, to: name, in: &state)
    }

    public static func renameSubset(
        _ subsetID: UUID,
        to name: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemStructureMutator.renameSubset(subsetID, to: name, in: &state)
    }

    @discardableResult
    public static func addGroup(in state: inout ProjectColorSystemEditingState) -> UUID {
        ProjectColorSystemStructureMutator.addGroup(in: &state)
    }

    public static func removeGroup(
        _ groupID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemStructureMutator.removeGroup(groupID, in: &state)
    }

    @discardableResult
    public static func addSubset(in state: inout ProjectColorSystemEditingState) -> UUID? {
        ProjectColorSystemStructureMutator.addSubset(in: &state)
    }

    public static func removeSubset(
        _ subsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemStructureMutator.removeSubset(subsetID, in: &state)
    }

    public static func normalizeColorSelection(in state: inout ProjectColorSystemEditingState) {
        ProjectColorSystemSelectionResolver.normalizeColorSelection(in: &state)
    }

    public static func selectGroup(
        _ groupID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemSelectionResolver.selectGroup(groupID, in: &state)
    }

    public static func selectSubset(
        _ subsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemSelectionResolver.selectSubset(subsetID, in: &state)
    }

    public static func setActiveStatus(
        _ statusName: String,
        in state: inout ProjectColorSystemEditingState
    ) {
        ProjectColorSystemSelectionResolver.setActiveStatus(statusName, in: &state)
    }

    public static func colorSystemSubsetLocation(
        for subsetID: UUID,
        in groups: [ColorSystemGroup]
    ) -> ProjectColorSystemSubsetLocation? {
        ProjectColorSystemSelectionResolver.colorSystemSubsetLocation(for: subsetID, in: groups)
    }

    public static func refreshScope(
        for role: WritableKeyPath<ColorRoles, RGBAColor>
    ) -> ProjectColorSystemRefreshScope {
        ProjectColorSystemRefreshDispatcher.refreshScope(for: role)
    }

    public static func refreshScope(
        for keyPath: WritableKeyPath<ColorSystemSubset, Bool>
    ) -> ProjectColorSystemRefreshScope {
        ProjectColorSystemRefreshDispatcher.refreshScope(for: keyPath)
    }

    public static func workspaceUsesEditedSubset(
        _ workspace: ProjectColorSystemWorkspaceUsageState,
        editedSubsetID: UUID
    ) -> Bool {
        ProjectColorSystemRefreshDispatcher.workspaceUsesEditedSubset(workspace, editedSubsetID: editedSubsetID)
    }

    public static func affectedInactiveFrameIDsSplit(
        in workspace: ProjectColorSystemWorkspaceUsageState,
        editedSubsetID: UUID
    ) -> (adjacent: [UUID], rest: [UUID]) {
        ProjectColorSystemRefreshDispatcher.affectedInactiveFrameIDsSplit(in: workspace, editedSubsetID: editedSubsetID)
    }
}
