import ColorAnimaAppEngine
import XCTest

final class AppEngineClientTests: XCTestCase {
    func testStatusHasUserVisibleOperationalState() {
        let status = AppEngineClient().status

        XCTAssertFalse(status.title.isEmpty)
        XCTAssertFalse(status.detail.isEmpty)
        XCTAssertEqual(status.kernelLinked, status.kernelVersion != nil)
    }

    func testStartupCheckCarriesStatusAndDetail() {
        let client = AppEngineClient()
        let check = client.runStartupCheck()

        XCTAssertEqual(check.status, client.status)
        XCTAssertFalse(check.detail.isEmpty)
    }
}
