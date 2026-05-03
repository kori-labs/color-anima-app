import Foundation

public struct ProjectRuleEditingWorkspaceState: Hashable, Equatable, Sendable {
    public var ruleEditing: CutWorkspaceRuleEditingState

    public init(ruleEditing: CutWorkspaceRuleEditingState = CutWorkspaceRuleEditingState()) {
        self.ruleEditing = ruleEditing
    }
}

public struct ProjectRuleEditingState: Hashable, Equatable, Sendable {
    public var activeCutID: UUID?
    public var workspaces: [UUID: ProjectRuleEditingWorkspaceState]

    public init(
        activeCutID: UUID? = nil,
        workspaces: [UUID: ProjectRuleEditingWorkspaceState] = [:]
    ) {
        self.activeCutID = activeCutID
        self.workspaces = workspaces
    }
}

public enum ProjectRuleEditingCoordinator {
    @discardableResult
    public static func addRule(
        _ rule: ColorRule,
        in state: inout ProjectRuleEditingState
    ) -> Bool {
        mutateActiveWorkspace(in: &state) { workspace in
            CutWorkspaceRuleEditingCoordinator.addRule(rule, in: &workspace.ruleEditing)
            return true
        }
    }

    @discardableResult
    public static func removeRule(
        id: UUID,
        in state: inout ProjectRuleEditingState
    ) -> Bool {
        mutateActiveWorkspace(in: &state) { workspace in
            CutWorkspaceRuleEditingCoordinator.removeRule(id: id, in: &workspace.ruleEditing)
        }
    }

    @discardableResult
    public static func moveRule(
        fromOffsets source: IndexSet,
        toOffset destination: Int,
        in state: inout ProjectRuleEditingState
    ) -> Bool {
        mutateActiveWorkspace(in: &state) { workspace in
            CutWorkspaceRuleEditingCoordinator.moveRule(
                fromOffsets: source,
                toOffset: destination,
                in: &workspace.ruleEditing
            )
        }
    }

    @discardableResult
    public static func updateRule(
        _ rule: ColorRule,
        in state: inout ProjectRuleEditingState
    ) -> Bool {
        mutateActiveWorkspace(in: &state) { workspace in
            CutWorkspaceRuleEditingCoordinator.updateRule(rule, in: &workspace.ruleEditing)
        }
    }

    @discardableResult
    public static func triggerWhatIfPreview(
        ruleID: UUID,
        simulatedColor: RGBAColor,
        in state: inout ProjectRuleEditingState
    ) -> Bool {
        mutateActiveWorkspace(in: &state) { workspace in
            CutWorkspaceRuleEditingCoordinator.triggerWhatIfPreview(
                ruleID: ruleID,
                simulatedColor: simulatedColor,
                in: &workspace.ruleEditing
            )
            return true
        }
    }

    @discardableResult
    public static func clearWhatIfPreview(
        in state: inout ProjectRuleEditingState
    ) -> Bool {
        mutateActiveWorkspace(in: &state) { workspace in
            CutWorkspaceRuleEditingCoordinator.clearWhatIfPreview(in: &workspace.ruleEditing)
            return true
        }
    }

    @discardableResult
    private static func mutateActiveWorkspace(
        in state: inout ProjectRuleEditingState,
        _ mutate: (inout ProjectRuleEditingWorkspaceState) -> Bool
    ) -> Bool {
        guard let activeCutID = state.activeCutID,
              var workspace = state.workspaces[activeCutID] else {
            return false
        }

        let didMutate = mutate(&workspace)
        guard didMutate else { return false }

        state.workspaces[activeCutID] = workspace
        return true
    }
}
