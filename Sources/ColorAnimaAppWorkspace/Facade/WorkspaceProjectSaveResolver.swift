import Foundation

@MainActor
struct WorkspaceProjectSaveResolver {
    private let prompting: any WorkspaceProjectInteractionPrompting

    init(prompting: any WorkspaceProjectInteractionPrompting) {
        self.prompting = prompting
    }

    func resolveSaveTargetURL(
        existingRootURL: URL?,
        title: String,
        suggestedName: String
    ) throws -> URL? {
        if let existingRootURL {
            return existingRootURL
        }

        return try prompting.chooseProjectDirectory(title: title, suggestedName: suggestedName)
    }
}
