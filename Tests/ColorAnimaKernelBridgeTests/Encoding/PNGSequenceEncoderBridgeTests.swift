import ColorAnimaKernelBridge
import Foundation
import XCTest

final class PNGSequenceEncoderBridgeTests: XCTestCase {

    // MARK: - Availability

    func testBridgeAvailabilityReflectsKernelSurface() {
        let bridge = PNGSequenceEncoderBridge()
        // Availability must be false until the core repo adds the C function.
        XCTAssertFalse(bridge.isPNGEncodingAvailable)
    }

    // MARK: - Result path: .unavailable fallback

    func testEncodeReturnsUnavailableForMinimalFrame() {
        let bridge = PNGSequenceEncoderBridge()
        let frame = EncoderInputFrame(
            width: 4,
            height: 4,
            bytesPerRow: 16,
            bytes: Data(repeating: 0, count: 64)
        )
        let result = bridge.encode(frame: frame)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .unavailable)
        case .success:
            XCTFail("Expected .failure(.unavailable) while kernel C function is not exposed")
        }
    }

    func testEncodeReturnsUnavailableForFullResolutionFrame() {
        let bridge = PNGSequenceEncoderBridge()
        let width = 1920
        let height = 1080
        let bytesPerRow = width * 4
        let frame = EncoderInputFrame(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            bytes: Data(repeating: 0xFF, count: bytesPerRow * height)
        )
        let result = bridge.encode(frame: frame)
        guard case .failure(let error) = result else {
            XCTFail("Expected .failure(.unavailable)")
            return
        }
        XCTAssertEqual(error, .unavailable)
    }

    // MARK: - DTO construction

    func testEncoderInputFrameEquality() {
        let a = EncoderInputFrame(
            width: 8,
            height: 8,
            bytesPerRow: 32,
            bytes: Data(repeating: 0xAB, count: 256)
        )
        let b = EncoderInputFrame(
            width: 8,
            height: 8,
            bytesPerRow: 32,
            bytes: Data(repeating: 0xAB, count: 256)
        )
        XCTAssertEqual(a, b)
    }

    func testEncoderInputFrameInequalityOnDifferentDimensions() {
        let a = EncoderInputFrame(width: 4, height: 4, bytesPerRow: 16, bytes: Data(count: 64))
        let b = EncoderInputFrame(width: 8, height: 4, bytesPerRow: 32, bytes: Data(count: 128))
        XCTAssertNotEqual(a, b)
    }

    func testEncoderFrameResultEquality() {
        let r1 = EncoderFrameResult(pngData: Data([0x89, 0x50, 0x4E, 0x47]))
        let r2 = EncoderFrameResult(pngData: Data([0x89, 0x50, 0x4E, 0x47]))
        XCTAssertEqual(r1, r2)
    }
}
