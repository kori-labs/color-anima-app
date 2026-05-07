import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct CutWorkspaceCanvasView: View {
    @Bindable var model: WorkspaceHostModel

    var body: some View {
        let presentation = model.canvasPresentation
        let regions = model.regions
        let activeWorkspace = model.activeCutWorkspace
        let isMultiRegionSelect = model.isMultiRegionSelect

        VStack(alignment: .leading, spacing: 12) {
            CutWorkspaceHeaderView(
                model: model,
                onImportAsset: importAsset,
                onImportTriSequence: importTriSequence
            )

            if let presentation {
                CanvasPreviewView(
                    presentation: presentation,
                    regions: regions,
                    onSelectImagePoint: { point, modifiers in
                        if let modifiers,
                           let imagePoint = point,
                           modifiers.contains(.additive) || modifiers.contains(.range) {
                            let regionID = activeWorkspace?.region(at: imagePoint)?.id
                            model.selectRegionWithModifiers(regionID, modifiers: modifiers)
                        } else {
                            model.selectRegion(at: point)
                        }
                    },
                    onAssignSubsetToRegion: { subsetID, regionID in
                        if isMultiRegionSelect,
                           activeWorkspace?.selectedRegionIDs.contains(regionID) == true {
                            model.batchAssignSelectedRegionsToSubset(subsetID)
                        } else {
                            model.assignRegion(regionID: regionID, toSubsetID: subsetID)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyCutWorkspacePlaceholderView(resolution: model.projectCanvasResolution)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            CutWorkspaceFrameStripView(model: model)
        }
        .padding(WorkspaceFoundation.Metrics.space5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func importAsset(_ kind: CutAssetKind) {
        assetImportCoordinator.importAsset(kind)
    }

    private func importTriSequence() {
        do {
            let prompting = FilePanelsWorkspaceAssetImportPrompting()
            guard let outlineURL = try prompting.openDirectory(title: "Select Outline Sequence Folder (Required)") else {
                return
            }
            let highlightURL = try prompting.openDirectory(title: "Select Highlight Sequence Folder (Optional)")
            let shadowURL = try prompting.openDirectory(title: "Select Shadow Sequence Folder (Optional)")
            assetImportCoordinator.importTriSequence(
                outlineDirectoryURL: outlineURL,
                highlightDirectoryURL: highlightURL,
                shadowDirectoryURL: shadowURL
            )
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private var assetImportCoordinator: WorkspaceAssetImportCoordinator {
        WorkspaceAssetImportCoordinator(
            prompting: FilePanelsWorkspaceAssetImportPrompting(),
            importAssetSequence: { kind, artworks in
                try model.importAssetSequence(kind, artworks: artworks)
            },
            importUnifiedLayers: { url in
                try model.importUnifiedLayers(from: url)
            },
            importUnifiedLayerSequence: { urls in
                try model.importUnifiedLayerSequence(from: urls)
            },
            importTriSequence: { plan in
                try model.importTriSequence(plan)
            },
            reportError: { message in
                model.errorMessage = message
            }
        )
    }
}
