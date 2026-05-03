import XCTest
@testable import ColorAnimaAppWorkspaceShell

final class ProjectSettingsDraftTests: XCTestCase {
    func testParsedResolutionReturnsValuesForValidInput() {
        let draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)

        XCTAssertEqual(draft.parsedResolution, .init(width: 1920, height: 1080))
    }

    func testParsedPlaybackFPSReturnsValueForValidInput() {
        let draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 24)

        XCTAssertEqual(draft.parsedPlaybackFPS, 24)
    }

    func testBlankInputIsRejected() {
        var draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)
        draft.widthText = " "
        draft.heightText = ""

        XCTAssertNil(draft.parsedResolution)
    }

    func testBlankFPSInputIsRejected() {
        var draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)
        draft.fpsText = " "

        XCTAssertNil(draft.parsedPlaybackFPS)
    }

    func testZeroInputIsRejected() {
        var draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)
        draft.widthText = "0"
        draft.heightText = "1080"

        XCTAssertNil(draft.parsedResolution)
    }

    func testZeroFPSInputIsRejected() {
        var draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)
        draft.fpsText = "0"

        XCTAssertNil(draft.parsedPlaybackFPS)
    }

    func testNegativeInputIsRejected() {
        var draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)
        draft.widthText = "-1"
        draft.heightText = "1080"

        XCTAssertNil(draft.parsedResolution)
    }

    func testNegativeFPSInputIsRejected() {
        var draft = ProjectSettingsDraft(initialResolution: .init(width: 1920, height: 1080), initialPlaybackFPS: 12)
        draft.fpsText = "-1"

        XCTAssertNil(draft.parsedPlaybackFPS)
    }
}
