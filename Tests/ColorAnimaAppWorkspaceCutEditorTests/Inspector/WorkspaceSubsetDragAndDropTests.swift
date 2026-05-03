import ColorAnimaAppWorkspaceApplication
import UniformTypeIdentifiers
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class WorkspaceSubsetDragAndDropTests: XCTestCase {
    func testSubsetDragPayloadItemProviderConformsToPlainText() {
        let payload = WorkspaceSubsetDragPayload(subsetID: UUID())

        XCTAssertTrue(payload.itemProvider().hasItemConformingToTypeIdentifier(UTType.text.identifier))
    }

    func testDragPreviewModelUsesActiveStatusPalette() {
        let activeRoles = ColorRoles(
            base: RGBAColor(red: 0.1, green: 0.2, blue: 0.3),
            highlight: RGBAColor(red: 0.4, green: 0.5, blue: 0.6),
            shadow: RGBAColor(red: 0.7, green: 0.8, blue: 0.9)
        )
        let subset = ColorSystemSubset(
            name: "skin",
            palettes: [
                StatusPalette(name: "default", roles: .neutral),
                StatusPalette(name: "night", roles: activeRoles),
            ]
        )

        let model = WorkspaceSubsetDragPreviewModel(subset: subset, activeStatusName: "night")

        XCTAssertEqual(model.title, "skin")
        XCTAssertEqual(model.colors, [activeRoles.base, activeRoles.highlight, activeRoles.shadow])
    }

    func testDragPreviewModelFallsBackToFirstPaletteWhenActiveStatusIsMissing() {
        let fallbackRoles = ColorRoles(
            base: RGBAColor(red: 0.2, green: 0.2, blue: 0.2),
            highlight: RGBAColor(red: 0.5, green: 0.5, blue: 0.5),
            shadow: RGBAColor(red: 0.8, green: 0.8, blue: 0.8)
        )
        let subset = ColorSystemSubset(
            name: "cape",
            palettes: [
                StatusPalette(name: "default", roles: fallbackRoles),
                StatusPalette(name: "night", roles: .neutral),
            ]
        )

        let model = WorkspaceSubsetDragPreviewModel(subset: subset, activeStatusName: "missing")

        XCTAssertEqual(model.colors, [fallbackRoles.base, fallbackRoles.highlight, fallbackRoles.shadow])
    }
}
