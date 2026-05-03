import SwiftUI
import XCTest
@testable import ColorAnimaAppWorkspacePlatformMacOS

@MainActor
final class MacOSColorBridgeTests: XCTestCase {
    func testRGBAColorFromSwiftUIColorUsesDeviceRGBComponents() throws {
        let converted = try XCTUnwrap(
            MacOSColorBridge.rgbaColor(
                from: Color(red: 0.2, green: 0.4, blue: 0.6, opacity: 0.8)
            )
        )

        XCTAssertEqual(converted.red, 0.2, accuracy: 0.001)
        XCTAssertEqual(converted.green, 0.4, accuracy: 0.001)
        XCTAssertEqual(converted.blue, 0.6, accuracy: 0.001)
        XCTAssertEqual(converted.alpha, 0.8, accuracy: 0.001)
    }
}
