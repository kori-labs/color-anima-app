import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import Foundation
import SwiftUI
import UniformTypeIdentifiers

package struct WorkspaceSubsetDragPayload: Equatable, Sendable {
    package let subsetID: UUID

    package init(subsetID: UUID) {
        self.subsetID = subsetID
    }

    package func itemProvider() -> NSItemProvider {
        NSItemProvider(object: NSString(string: subsetID.uuidString))
    }
}

package struct WorkspaceSubsetDragPreviewModel: Equatable {
    package let title: String
    package let colors: [RGBAColor]

    package init(subset: ColorSystemSubset, activeStatusName: String) {
        let palette = subset.palettes.first(where: { $0.name == activeStatusName }) ?? subset.palettes.first
        let roles = palette?.roles ?? .neutral

        self.title = subset.name
        self.colors = [roles.base, roles.highlight, roles.shadow]
    }
}

package struct WorkspaceSubsetDragPreview: View {
    let model: WorkspaceSubsetDragPreviewModel

    package init(model: WorkspaceSubsetDragPreviewModel) {
        self.model = model
    }

    package var body: some View {
        HStack(spacing: 12) {
            Text(model.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                .lineLimit(1)

            HStack(spacing: 8) {
                ForEach(Array(model.colors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .stroke(WorkspaceChromeStyle.Inspector.swatchStroke, lineWidth: 1)
                        }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .chromeCard(
            fill: WorkspaceChromeStyle.Inspector.idleCardFill,
            stroke: WorkspaceChromeStyle.Inspector.selectedCardStroke,
            cornerRadius: 14
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}

@MainActor
package enum WorkspaceSubsetDragContext {
    package static var payload: WorkspaceSubsetDragPayload?
    package static var dropPerformed: Bool = false
}

@MainActor
package struct RegionRowDropDelegate: DropDelegate {
    package let regionID: UUID
    package let onAssign: @MainActor @Sendable (UUID, UUID) -> Void
    @Binding package var isDropTargeted: Bool

    package init(
        regionID: UUID,
        onAssign: @escaping @MainActor @Sendable (UUID, UUID) -> Void,
        isDropTargeted: Binding<Bool>
    ) {
        self.regionID = regionID
        self.onAssign = onAssign
        self._isDropTargeted = isDropTargeted
    }

    package func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    package func dropEntered(info: DropInfo) {
        guard !WorkspaceSubsetDragContext.dropPerformed else { return }
        isDropTargeted = true
    }

    package func dropUpdated(info: DropInfo) -> DropProposal? {
        guard !WorkspaceSubsetDragContext.dropPerformed else {
            return DropProposal(operation: .move)
        }
        return DropProposal(operation: .move)
    }

    package func dropExited(info: DropInfo) {
        isDropTargeted = false
    }

    package func performDrop(info: DropInfo) -> Bool {
        WorkspaceSubsetDragContext.dropPerformed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WorkspaceSubsetDragContext.dropPerformed = false
        }
        isDropTargeted = false

        if let payload = WorkspaceSubsetDragContext.payload {
            Task { @MainActor in
                onAssign(payload.subsetID, regionID)
            }
            WorkspaceSubsetDragContext.payload = nil
            return true
        }

        guard let provider = info.itemProviders(for: [.text]).first else {
            return false
        }

        let capturedOnAssign = onAssign
        let capturedRegionID = regionID
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let string = item as? String,
                  let subsetID = UUID(uuidString: string)
            else {
                return
            }
            Task { @MainActor in
                capturedOnAssign(subsetID, capturedRegionID)
            }
        }
        return true
    }
}
