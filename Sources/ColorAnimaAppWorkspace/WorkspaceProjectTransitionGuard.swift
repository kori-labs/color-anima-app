import Foundation

@MainActor
enum WorkspaceProjectTransitionDecision: Equatable {
    case proceed
    case save
    case cancel
}

@MainActor
struct WorkspaceProjectTransitionGuard {
    private let prompting: any WorkspaceProjectInteractionPrompting

    init(prompting: any WorkspaceProjectInteractionPrompting) {
        self.prompting = prompting
    }

    func confirmTransitionIfNeeded(
        dirtyCutCount: Int,
        hasUnsavedChanges: Bool
    ) throws -> WorkspaceProjectTransitionDecision {
        guard hasUnsavedChanges else { return .proceed }

        switch try prompting.confirmUnsavedChanges(dirtyCutCount: dirtyCutCount) {
        case .save:
            return .save
        case .discard:
            return .proceed
        case .cancel:
            return .cancel
        }
    }
}
