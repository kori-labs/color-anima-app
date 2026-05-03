import ColorAnimaKernelBridge
import Foundation
import XCTest

final class KernelBridgeTests: XCTestCase {
    func testStatusReflectsBinaryTargetAvailability() {
        let status = KernelBridge().status

        if ProcessInfo.processInfo.environment["COLOR_ANIMA_KERNEL_PATH"] != nil ||
            ProcessInfo.processInfo.environment["COLOR_ANIMA_KERNEL_URL"] != nil {
            XCTAssertEqual(status.mode, .linked)
        }

        switch status.mode {
        case .linked:
            XCTAssertNotNil(status.version)
            XCTAssertTrue(status.isLinked)
        case .unavailable:
            XCTAssertNil(status.version)
            XCTAssertFalse(status.isLinked)
        }
    }

    func testSmokeCheckUsesCurrentStatus() {
        let bridge = KernelBridge()
        let smokeResult = bridge.runSmokeCheck()

        XCTAssertEqual(smokeResult.status, bridge.status)
        XCTAssertFalse(smokeResult.detail.isEmpty)
    }
}
