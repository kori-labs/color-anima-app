import ColorAnimaAppWorkspaceApplication
import Foundation

@MainActor
struct WorkspacePendingCloseCoordinator {
    private let saveResolver: WorkspaceProjectSaveResolver
    private let resolveClose: (Bool, URL?) throws -> Void
    private let reportError: (String) -> Void

    init(
        saveResolver: WorkspaceProjectSaveResolver,
        resolveClose: @escaping (Bool, URL?) throws -> Void,
        reportError: @escaping (String) -> Void
    ) {
        self.saveResolver = saveResolver
        self.resolveClose = resolveClose
        self.reportError = reportError
    }

    func resolvePendingClose(
        request: WorkspacePendingCloseRequest?,
        projectName: String,
        existingRootURL: URL?,
        saveChanges: Bool
    ) {
        do {
            guard request != nil else { return }
            if saveChanges {
                let suggestedName = projectName.replacingOccurrences(of: "/", with: "-")
                guard let saveURL = try saveResolver.resolveSaveTargetURL(
                    existingRootURL: existingRootURL,
                    title: "Save Project",
                    suggestedName: suggestedName
                ) else {
                    return
                }
                try resolveClose(true, saveURL)
            } else {
                try resolveClose(false, nil)
            }
        } catch {
            reportError(error.localizedDescription)
        }
    }
}
