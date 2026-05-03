import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct SubsetCardPaletteLookup {
    package static func palette(
        in subset: ColorSystemSubset,
        activeStatusName: String
    ) -> StatusPalette? {
        subset.palettes.first(where: { $0.name == activeStatusName }) ?? subset.palettes.first
    }
}

package extension View {
    func subsetCardDragInteraction(
        subset: ColorSystemSubset,
        activeStatusName: String,
        isEditing: Bool
    ) -> some View {
        modifier(
            SubsetCardDragInteractionModifier(
                subset: subset,
                activeStatusName: activeStatusName,
                isEditing: isEditing
            )
        )
    }
}

private struct SubsetCardDragInteractionModifier: ViewModifier {
    let subset: ColorSystemSubset
    let activeStatusName: String
    let isEditing: Bool

    func body(content: Content) -> some View {
        guard isEditing == false else {
            return AnyView(content)
        }

        let previewModel = WorkspaceSubsetDragPreviewModel(
            subset: subset,
            activeStatusName: activeStatusName
        )

        return AnyView(
            content.onDrag {
                let payload = WorkspaceSubsetDragPayload(subsetID: subset.id)
                WorkspaceSubsetDragContext.payload = payload
                return payload.itemProvider()
            } preview: {
                WorkspaceSubsetDragPreview(model: previewModel)
            }
        )
    }
}
