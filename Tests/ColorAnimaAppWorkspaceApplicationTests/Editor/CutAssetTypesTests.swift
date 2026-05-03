import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutAssetTypesTests: XCTestCase {
    func testStorageBasenamesMatchPersistedAssetNames() {
        XCTAssertEqual(CutAssetKind.outline.storageBasename, "outline")
        XCTAssertEqual(CutAssetKind.highlightLine.storageBasename, "highlight-line")
        XCTAssertEqual(CutAssetKind.shadowLine.storageBasename, "shadow-line")
    }

    func testCatalogSubscriptReadsAndWritesByKind() {
        var catalog = CutAssetCatalog()
        let outline = CutAssetRef(kind: .outline, relativePath: "assets/outline.png")
        let highlight = CutAssetRef(kind: .highlightLine, relativePath: "assets/highlight.png")

        catalog[.outline] = outline
        catalog[.highlightLine] = highlight

        XCTAssertEqual(catalog[.outline], outline)
        XCTAssertEqual(catalog[.highlightLine], highlight)
        XCTAssertNil(catalog[.shadowLine])
    }
}
