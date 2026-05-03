import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspacePlatformMacOS
import Foundation
import UniformTypeIdentifiers

@MainActor
protocol WorkspaceAssetImportPrompting {
    func openImage(title: String) throws -> URL?
    func openDirectory(title: String) throws -> URL?
}

@MainActor
struct FilePanelsWorkspaceAssetImportPrompting: WorkspaceAssetImportPrompting {
    func openImage(title: String) throws -> URL? {
        try FilePanels.openImage(title: title)
    }

    func openDirectory(title: String) throws -> URL? {
        try FilePanels.openProjectDirectory(title: title)
    }
}

struct TriSequenceImportPlan {
    let outlineArtworks: [ImportedArtwork]
    let highlightArtworks: [ImportedArtwork]?
    let shadowArtworks: [ImportedArtwork]?

    var frameCount: Int { outlineArtworks.count }
}

private enum WorkspaceAssetSequenceImportError: LocalizedError {
    case missingImages(folderName: String)

    var errorDescription: String? {
        switch self {
        case let .missingImages(folderName):
            "\(folderName) folder does not contain any image files."
        }
    }
}

@MainActor
struct WorkspaceAssetImportCoordinator {
    private let prompting: any WorkspaceAssetImportPrompting
    private let importAssetSequence: (CutAssetKind, [ImportedArtwork]) throws -> Void
    private let dispatchUnifiedLayers: (URL) throws -> Void
    private let dispatchUnifiedLayerSequence: ([URL]) throws -> Void
    private let dispatchTriSequence: (TriSequenceImportPlan) throws -> Void
    private let reportError: (String) -> Void

    init(
        prompting: any WorkspaceAssetImportPrompting,
        importAssetSequence: @escaping (CutAssetKind, [ImportedArtwork]) throws -> Void,
        importUnifiedLayers: @escaping (URL) throws -> Void,
        importUnifiedLayerSequence: @escaping ([URL]) throws -> Void,
        importTriSequence: @escaping (TriSequenceImportPlan) throws -> Void,
        reportError: @escaping (String) -> Void
    ) {
        self.prompting = prompting
        self.importAssetSequence = importAssetSequence
        self.dispatchUnifiedLayers = importUnifiedLayers
        self.dispatchUnifiedLayerSequence = importUnifiedLayerSequence
        self.dispatchTriSequence = importTriSequence
        self.reportError = reportError
    }

    func importAsset(_ kind: CutAssetKind) {
        do {
            guard let directoryURL = try prompting.openDirectory(title: "Import \(kind.importTitle) Frames Folder") else { return }
            let artworks = try loadArtworks(in: directoryURL, folderName: kind.importTitle)
            try importAssetSequence(kind, artworks)
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func importUnifiedLayers() {
        do {
            guard let url = try prompting.openImage(title: "Import Composite Layer Image") else { return }
            try dispatchUnifiedLayers(url)
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func importUnifiedLayerSequence() {
        do {
            guard let directoryURL = try prompting.openDirectory(title: "Import Composite Layer Frames Folder") else { return }
            let artworkURLs = try imageFileURLs(in: directoryURL)
            guard artworkURLs.isEmpty == false else {
                throw WorkspaceAssetSequenceImportError.missingImages(folderName: directoryURL.lastPathComponent)
            }
            try dispatchUnifiedLayerSequence(artworkURLs)
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func importTriSequence(
        outlineDirectoryURL: URL,
        highlightDirectoryURL: URL?,
        shadowDirectoryURL: URL?
    ) {
        do {
            let outlineArtworks = try loadArtworks(in: outlineDirectoryURL, folderName: CutAssetKind.outline.importTitle)
            let highlightArtworks = try highlightDirectoryURL.map {
                try loadArtworks(in: $0, folderName: CutAssetKind.highlightLine.importTitle)
            }
            let shadowArtworks = try shadowDirectoryURL.map {
                try loadArtworks(in: $0, folderName: CutAssetKind.shadowLine.importTitle)
            }

            let plan = TriSequenceImportPlan(
                outlineArtworks: outlineArtworks,
                highlightArtworks: highlightArtworks,
                shadowArtworks: shadowArtworks
            )
            try dispatchTriSequence(plan)
        } catch {
            reportError(error.localizedDescription)
        }
    }

    private func loadArtworks(in directoryURL: URL, folderName: String) throws -> [ImportedArtwork] {
        let artworkURLs = try imageFileURLs(in: directoryURL)
        guard artworkURLs.isEmpty == false else {
            throw WorkspaceAssetSequenceImportError.missingImages(folderName: folderName)
        }
        return try artworkURLs.map(ImportedArtworkLoader.load(from:))
    }

    private func imageFileURLs(in directoryURL: URL) throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { url in
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    return false
                }
                guard let fileType = UTType(filenameExtension: url.pathExtension.lowercased()) else {
                    return false
                }
                return fileType.conforms(to: .image)
            }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }
}

private extension CutAssetKind {
    var importTitle: String {
        switch self {
        case .outline:
            "Outline"
        case .highlightLine:
            "Highlight Line"
        case .shadowLine:
            "Shadow Line"
        }
    }
}
