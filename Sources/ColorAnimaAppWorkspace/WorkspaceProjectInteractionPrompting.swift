import ColorAnimaAppWorkspacePlatformMacOS
import Foundation

@MainActor
enum WorkspaceProjectInteractionChoice {
    case save
    case discard
    case cancel
}

@MainActor
protocol WorkspaceProjectInteractionPrompting {
    func chooseProjectDirectory(title: String, suggestedName: String) throws -> URL?
    func openProjectDirectory(title: String) throws -> URL?
    func confirmUnsavedChanges(dirtyCutCount: Int) throws -> WorkspaceProjectInteractionChoice
}

@MainActor
struct FilePanelsWorkspaceProjectInteractionPrompting: WorkspaceProjectInteractionPrompting {
    func chooseProjectDirectory(title: String, suggestedName: String) throws -> URL? {
        try FilePanels.chooseProjectDirectory(title: title, suggestedName: suggestedName)
    }

    func openProjectDirectory(title: String) throws -> URL? {
        try FilePanels.openProjectDirectory(title: title)
    }

    func confirmUnsavedChanges(dirtyCutCount: Int) throws -> WorkspaceProjectInteractionChoice {
        switch try FilePanels.confirmUnsavedChanges(dirtyCutCount: dirtyCutCount) {
        case .save:
            .save
        case .discard:
            .discard
        case .cancel:
            .cancel
        }
    }
}
