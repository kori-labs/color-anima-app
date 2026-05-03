import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspacePlatformMacOS
import Foundation

@MainActor
protocol WorkspaceExportInteractionPrompting {
    func savePNG(for definition: WorkspaceExportDefinition) throws -> URL?
    func saveDirectory(title: String) -> URL?
}

@MainActor
struct FilePanelsWorkspaceExportInteractionPrompting: WorkspaceExportInteractionPrompting {
    func savePNG(for definition: WorkspaceExportDefinition) throws -> URL? {
        try FilePanels.savePNG(title: definition.title, suggestedName: definition.suggestedFilename)
    }

    func saveDirectory(title: String) -> URL? {
        FilePanels.saveDirectory(title: title)
    }
}

@MainActor
struct WorkspaceExportInteractionCoordinator {
    private let prompting: any WorkspaceExportInteractionPrompting
    private let exportPreview: (WorkspaceExportDefinition, URL) -> Void
    private let exportPNGSequence: (URL) -> Void
    private let reportError: (String) -> Void

    init(
        prompting: any WorkspaceExportInteractionPrompting,
        exportPreview: @escaping (WorkspaceExportDefinition, URL) -> Void,
        exportPNGSequence: @escaping (URL) -> Void,
        reportError: @escaping (String) -> Void
    ) {
        self.prompting = prompting
        self.exportPreview = exportPreview
        self.exportPNGSequence = exportPNGSequence
        self.reportError = reportError
    }

    func exportVisiblePreview() {
        export(.visiblePreview)
    }

    func exportReviewPreview() {
        export(.reviewPreview)
    }

    func exportSequence() {
        guard let url = prompting.saveDirectory(title: "Export PNG Sequence") else { return }
        exportPNGSequence(url)
    }

    private func export(_ definition: WorkspaceExportDefinition) {
        do {
            guard let url = try prompting.savePNG(for: definition) else { return }
            exportPreview(definition, url)
        } catch {
            reportError(error.localizedDescription)
        }
    }
}
