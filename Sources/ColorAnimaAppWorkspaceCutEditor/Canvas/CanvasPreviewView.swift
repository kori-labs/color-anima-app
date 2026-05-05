import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI
import UniformTypeIdentifiers

package struct CanvasPreviewView: View {
    let presentation: CutWorkspaceCanvasPresentation
    let regions: [CanvasSelectionRegion]
    let onSelectImagePoint: (CGPoint?, WorkspaceSelectionModifiers?) -> Void
    let onAssignSubsetToRegion: @MainActor @Sendable (UUID, UUID) -> Void

    @State var zoomScale: CGFloat = 1
    @State var committedOffset: CGSize = .zero
    @State private var dropTargetRegionID: UUID?
    @GestureState var gestureMagnification: CGFloat = 1
    @GestureState var dragTranslation: CGSize = .zero

    package init(
        presentation: CutWorkspaceCanvasPresentation,
        regions: [CanvasSelectionRegion],
        onSelectImagePoint: @escaping (CGPoint?, WorkspaceSelectionModifiers?) -> Void,
        onAssignSubsetToRegion: @escaping @MainActor @Sendable (UUID, UUID) -> Void
    ) {
        self.presentation = presentation
        self.regions = regions
        self.onSelectImagePoint = onSelectImagePoint
        self.onAssignSubsetToRegion = onAssignSubsetToRegion
    }

    package var body: some View {
        GeometryReader { geometry in
            let imageSize = presentation.imageSize
            let fittedRect = CanvasPreviewLayoutMath.aspectFitRect(imageSize: imageSize, in: geometry.size)
            let effectiveZoomScale = CanvasPreviewLayoutMath.clampedZoom(
                zoomScale * gestureMagnification,
                minimumZoomScale: presentation.minimumZoomScale,
                maximumZoomScale: presentation.maximumZoomScale
            )
            let combinedOffset = CGSize(
                width: committedOffset.width + dragTranslation.width,
                height: committedOffset.height + dragTranslation.height
            )
            let constrainedOffset = CanvasPreviewLayoutMath.clampedOffset(
                combinedOffset,
                containerSize: geometry.size,
                fittedRect: fittedRect,
                zoomScale: effectiveZoomScale
            )
            let displayRect = CanvasPreviewLayoutMath.scaledRect(
                from: fittedRect,
                zoomScale: effectiveZoomScale,
                offset: constrainedOffset
            )

            canvasLayerStack(
                presentation: presentation,
                displayRect: displayRect,
                effectiveZoomScale: effectiveZoomScale,
                containerSize: geometry.size,
                fittedRect: fittedRect,
                dropTargetRegion: currentDropTarget(in: regions)
            )
            .contentShape(.rect(cornerRadius: WorkspaceFoundation.Metrics.frameCardCornerRadius))
            .simultaneousGesture(canvasTapGesture(imageSize: imageSize, displayRect: displayRect))
            .simultaneousGesture(
                canvasDragGesture(
                    containerSize: geometry.size,
                    fittedRect: fittedRect,
                    effectiveZoomScale: effectiveZoomScale
                )
            )
            .simultaneousGesture(
                canvasMagnificationGesture(
                    containerSize: geometry.size,
                    fittedRect: fittedRect
                )
            )
            .background {
                GeometryReader { _ in
                    Color.clear.onDrop(
                        of: [UTType.text.identifier],
                        delegate: CanvasSubsetDropDelegate(
                            imageSize: imageSize,
                            displayRect: displayRect,
                            regions: regions,
                            draggedPayload: { WorkspaceSubsetDragContext.payload },
                            setDropTargetRegionID: { dropTargetRegionID = $0 },
                            performAssignment: onAssignSubsetToRegion,
                            clearDragState: {
                                WorkspaceSubsetDragContext.payload = nil
                                dropTargetRegionID = nil
                            }
                        )
                    )
                }
            }
        }
        .clipShape(.rect(cornerRadius: WorkspaceFoundation.Metrics.frameCardCornerRadius))
    }

    private func currentDropTarget(in regions: [CanvasSelectionRegion]) -> CanvasSelectionRegion? {
        guard let dropTargetRegionID else { return nil }
        return regions.first(where: { $0.id == dropTargetRegionID })
    }
}

@MainActor
private struct CanvasSubsetDropDelegate: DropDelegate {
    let imageSize: CGSize
    let displayRect: CGRect
    let regions: [CanvasSelectionRegion]
    let draggedPayload: () -> WorkspaceSubsetDragPayload?
    let setDropTargetRegionID: (UUID?) -> Void
    let performAssignment: @MainActor @Sendable (UUID, UUID) -> Void
    let clearDragState: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard !WorkspaceSubsetDragContext.dropPerformed else { return }
        setDropTargetRegionID(resolvedRegionID(for: info))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard !WorkspaceSubsetDragContext.dropPerformed else {
            return DropProposal(operation: .move)
        }
        let regionID = resolvedRegionID(for: info)
        setDropTargetRegionID(regionID)
        guard regionID != nil else {
            return DropProposal(operation: .forbidden)
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        WorkspaceSubsetDragContext.dropPerformed = false
        setDropTargetRegionID(nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        WorkspaceSubsetDragContext.dropPerformed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WorkspaceSubsetDragContext.dropPerformed = false
        }
        setDropTargetRegionID(nil)
        defer {
            clearDragState()
        }

        guard let regionID = resolvedRegionID(for: info) else {
            return false
        }

        if let payload = draggedPayload() {
            Task { @MainActor in
                performAssignment(payload.subsetID, regionID)
            }
            return true
        }

        guard let provider = info.itemProviders(for: [UTType.text]).first
        else {
            return false
        }

        let capturedPerformAssignment = performAssignment
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let string = item as? String,
                  let subsetID = UUID(uuidString: string)
            else {
                return
            }
            Task { @MainActor in
                capturedPerformAssignment(subsetID, regionID)
            }
        }
        return true
    }

    private func resolvedRegionID(for info: DropInfo) -> UUID? {
        guard info.hasItemsConforming(to: [UTType.text.identifier]),
              let imagePoint = CanvasPreviewLayoutMath.mapViewPointToImage(
                info.location,
                imageSize: imageSize,
                displayRect: displayRect
              )
        else {
            return nil
        }

        return CutWorkspaceRegionHitTesting.region(
            at: imagePoint,
            imageSize: imageSize,
            in: regions
        )?.id
    }
}
