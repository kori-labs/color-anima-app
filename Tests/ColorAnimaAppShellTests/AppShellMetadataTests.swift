import ColorAnimaAppShell
import XCTest

final class AppShellMetadataTests: XCTestCase {
    func testPublicMetadataIsPresent() {
        XCTAssertEqual(AppShellMetadata.displayName, "Color Anima")
        XCTAssertFalse(AppShellMetadata.repositoryRole.isEmpty)
        XCTAssertFalse(AppShellMetadata.statusLine.isEmpty)
        XCTAssertGreaterThanOrEqual(AppShellMetadata.operationalSurfaces.count, 3)
    }
}
