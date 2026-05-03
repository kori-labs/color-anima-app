import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectPlaybackTimingTests: XCTestCase {
    func testFrameDurationNanosecondsForDefaultFPS() {
        XCTAssertEqual(ProjectPlaybackTiming.frameDurationNanoseconds(for: 12), 83_333_333)
    }

    func testFrameDurationNanosecondsForHigherFPS() {
        XCTAssertEqual(ProjectPlaybackTiming.frameDurationNanoseconds(for: 24), 41_666_666)
    }

    func testResolvedFramesPerSecondClampsToSupportedRange() {
        XCTAssertEqual(ProjectPlaybackTiming.resolvedFramesPerSecond(0), 1)
        XCTAssertEqual(ProjectPlaybackTiming.resolvedFramesPerSecond(240), 240)
        XCTAssertEqual(ProjectPlaybackTiming.resolvedFramesPerSecond(1_000_000_000), 240)
    }

    func testFrameDurationNanosecondsNeverReturnsZero() {
        XCTAssertEqual(ProjectPlaybackTiming.frameDurationNanoseconds(for: 1_000_000_000), 4_166_666)
    }
}
