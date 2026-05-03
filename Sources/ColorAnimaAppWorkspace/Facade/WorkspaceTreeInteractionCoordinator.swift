import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspacePlatformMacOS
import Foundation

@MainActor
protocol WorkspaceTreeInteractionPrompting {
    func promptForName(title: String, message: String, defaultValue: String) throws -> String?
}

@MainActor
struct FilePanelsWorkspaceTreeInteractionPrompting: WorkspaceTreeInteractionPrompting {
    func promptForName(title: String, message: String, defaultValue: String) throws -> String? {
        try FilePanels.promptForName(title: title, message: message, defaultValue: defaultValue)
    }
}

@MainActor
struct WorkspaceTreeInteractionCoordinator {
    private let prompting: any WorkspaceTreeInteractionPrompting
    private let renameNode: (UUID, String) throws -> Void
    private let reportError: (String) -> Void

    init(
        prompting: any WorkspaceTreeInteractionPrompting = FilePanelsWorkspaceTreeInteractionPrompting(),
        renameNode: @escaping (UUID, String) throws -> Void,
        reportError: @escaping (String) -> Void
    ) {
        self.prompting = prompting
        self.renameNode = renameNode
        self.reportError = reportError
    }

    func renameSelectedNode(_ selectedNode: WorkspaceProjectTreeNode?) {
        do {
            guard let selectedNode else { return }
            let message = "Enter a new name for the selected \(selectedNode.kind.rawValue)."
            guard let name = try prompting.promptForName(
                title: "Rename \(selectedNode.kind.rawValue.capitalized)",
                message: message,
                defaultValue: selectedNode.name
            ) else {
                return
            }
            try renameNode(selectedNode.id, name)
        } catch {
            reportError(error.localizedDescription)
        }
    }
}
