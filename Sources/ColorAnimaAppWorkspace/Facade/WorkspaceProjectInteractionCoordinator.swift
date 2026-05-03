import ColorAnimaAppWorkspaceApplication
import Foundation

@MainActor
struct WorkspaceProjectInteractionCoordinator {
    private let prompting: any WorkspaceProjectInteractionPrompting
    private let transitionGuard: WorkspaceProjectTransitionGuard
    private let saveResolver: WorkspaceProjectSaveResolver
    private let pendingCloseCoordinator: WorkspacePendingCloseCoordinator
    private let createProject: (URL) throws -> Void
    private let openProject: (URL) throws -> Void
    private let saveProject: (URL) throws -> URL?
    private let clearError: () -> Void
    private let reportError: (String) -> Void

    init(
        prompting: any WorkspaceProjectInteractionPrompting,
        createProject: @escaping (URL) throws -> Void,
        openProject: @escaping (URL) throws -> Void,
        saveProject: @escaping (URL) throws -> URL?,
        resolveClose: @escaping (Bool, URL?) throws -> Void,
        clearError: @escaping () -> Void,
        reportError: @escaping (String) -> Void
    ) {
        let saveResolver = WorkspaceProjectSaveResolver(prompting: prompting)
        self.prompting = prompting
        self.transitionGuard = WorkspaceProjectTransitionGuard(prompting: prompting)
        self.saveResolver = saveResolver
        self.pendingCloseCoordinator = WorkspacePendingCloseCoordinator(
            saveResolver: saveResolver,
            resolveClose: resolveClose,
            reportError: reportError
        )
        self.createProject = createProject
        self.openProject = openProject
        self.saveProject = saveProject
        self.clearError = clearError
        self.reportError = reportError
    }

    func newProject(
        projectName: String,
        existingRootURL: URL?,
        dirtyCutCount: Int,
        hasUnsavedChanges: Bool
    ) {
        do {
            guard try confirmProjectTransitionIfNeeded(
                projectName: projectName,
                existingRootURL: existingRootURL,
                dirtyCutCount: dirtyCutCount,
                hasUnsavedChanges: hasUnsavedChanges
            ) else {
                return
            }

            let suggestedName = sanitizedProjectName(projectName)
            guard let url = try prompting.chooseProjectDirectory(
                title: "Create Project",
                suggestedName: suggestedName
            ) else {
                return
            }

            try createProject(url)
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func openProject(
        projectName: String,
        existingRootURL: URL?,
        dirtyCutCount: Int,
        hasUnsavedChanges: Bool
    ) {
        do {
            guard try confirmProjectTransitionIfNeeded(
                projectName: projectName,
                existingRootURL: existingRootURL,
                dirtyCutCount: dirtyCutCount,
                hasUnsavedChanges: hasUnsavedChanges
            ) else {
                return
            }

            guard let url = try prompting.openProjectDirectory(title: "Open Project Folder") else { return }
            try openProject(url)
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func saveProject(
        projectName: String,
        existingRootURL: URL?
    ) {
        do {
            guard try saveProjectIfNeeded(
                projectName: projectName,
                existingRootURL: existingRootURL
            ) != nil else {
                return
            }
            clearError()
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func resolvePendingClose(
        request: WorkspacePendingCloseRequest?,
        projectName: String,
        existingRootURL: URL?,
        saveChanges: Bool
    ) {
        pendingCloseCoordinator.resolvePendingClose(
            request: request,
            projectName: projectName,
            existingRootURL: existingRootURL,
            saveChanges: saveChanges
        )
    }

    private func confirmProjectTransitionIfNeeded(
        projectName: String,
        existingRootURL: URL?,
        dirtyCutCount: Int,
        hasUnsavedChanges: Bool
    ) throws -> Bool {
        switch try transitionGuard.confirmTransitionIfNeeded(
            dirtyCutCount: dirtyCutCount,
            hasUnsavedChanges: hasUnsavedChanges
        ) {
        case .proceed:
            return true
        case .save:
            return try saveProjectIfNeeded(
                projectName: projectName,
                existingRootURL: existingRootURL
            ) != nil
        case .cancel:
            return false
        }
    }

    private func saveProjectIfNeeded(
        projectName: String,
        existingRootURL: URL?
    ) throws -> URL? {
        let suggestedName = sanitizedProjectName(projectName)
        guard let url = try saveResolver.resolveSaveTargetURL(
            existingRootURL: existingRootURL,
            title: "Save Project",
            suggestedName: suggestedName
        ) else {
            return nil
        }

        return try saveProject(url)
    }

    private func sanitizedProjectName(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
    }
}
