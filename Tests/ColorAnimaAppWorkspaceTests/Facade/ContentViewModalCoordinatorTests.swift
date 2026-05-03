import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class ContentViewModalCoordinatorTests: XCTestCase {
    func testSyncPromptsRequiredProjectSettingsWhenResolutionMissing() {
        let activator = MockContentViewModalActivating()
        let coordinator = ContentViewModalCoordinator(activator: activator)
        let resolution = ProjectCanvasResolution(width: 1920, height: 1080)
        var state = ContentViewModalState()
        var onboardingMarkCount = 0

        coordinator.syncModalPresentation(
            state: &state,
            requiresProjectCanvasResolutionSetup: true,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 12,
            shouldAutoPresentEmptyCutOnboarding: true,
            markEmptyCutOnboardingPresented: { onboardingMarkCount += 1 }
        )

        XCTAssertEqual(activator.activationCount, 1)
        XCTAssertEqual(state.projectSettingsPresentation?.initialResolution, resolution)
        XCTAssertEqual(state.projectSettingsPresentation?.initialPlaybackFPS, 12)
        XCTAssertEqual(state.projectSettingsPresentation?.isRequired, true)
        XCTAssertFalse(state.isCutOnboardingPresented)
        XCTAssertEqual(onboardingMarkCount, 0)
    }

    func testPresentProjectSettingsSeedsResolvedPlaybackFPS() {
        let activator = MockContentViewModalActivating()
        let coordinator = ContentViewModalCoordinator(activator: activator)
        let resolution = ProjectCanvasResolution(width: 1920, height: 1080)
        var state = ContentViewModalState()

        coordinator.presentProjectSettings(
            state: &state,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 24
        )

        XCTAssertEqual(activator.activationCount, 1)
        XCTAssertEqual(state.projectSettingsPresentation?.initialResolution, resolution)
        XCTAssertEqual(state.projectSettingsPresentation?.initialPlaybackFPS, 24)
        XCTAssertEqual(state.projectSettingsPresentation?.isRequired, false)
    }

    func testSyncAutoPresentsEmptyCutOnboardingOnce() {
        let activator = MockContentViewModalActivating()
        let coordinator = ContentViewModalCoordinator(activator: activator)
        let resolution = ProjectCanvasResolution(width: 1920, height: 1080)
        var state = ContentViewModalState()
        var onboardingMarkCount = 0

        coordinator.syncModalPresentation(
            state: &state,
            requiresProjectCanvasResolutionSetup: false,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 12,
            shouldAutoPresentEmptyCutOnboarding: true,
            markEmptyCutOnboardingPresented: { onboardingMarkCount += 1 }
        )

        XCTAssertEqual(activator.activationCount, 0)
        XCTAssertEqual(onboardingMarkCount, 1)
        XCTAssertTrue(state.isCutOnboardingPresented)
        XCTAssertNil(state.projectSettingsPresentation)

        state.isCutOnboardingPresented = false
        coordinator.syncModalPresentation(
            state: &state,
            requiresProjectCanvasResolutionSetup: false,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 12,
            shouldAutoPresentEmptyCutOnboarding: false,
            markEmptyCutOnboardingPresented: { onboardingMarkCount += 1 }
        )

        XCTAssertFalse(state.isCutOnboardingPresented)
        XCTAssertEqual(onboardingMarkCount, 1)
    }

    func testPresentProjectSettingsResetsOnboardingState() {
        let activator = MockContentViewModalActivating()
        let coordinator = ContentViewModalCoordinator(activator: activator)
        let resolution = ProjectCanvasResolution(width: 1280, height: 720)
        var state = ContentViewModalState(isCutOnboardingPresented: true)

        coordinator.presentProjectSettings(
            state: &state,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 30
        )

        XCTAssertEqual(activator.activationCount, 1)
        XCTAssertFalse(state.isCutOnboardingPresented)
        XCTAssertEqual(state.projectSettingsPresentation?.initialResolution, resolution)
        XCTAssertEqual(state.projectSettingsPresentation?.initialPlaybackFPS, 30)
        XCTAssertEqual(state.projectSettingsPresentation?.isRequired, false)
    }

    func testSyncClearsRequiredProjectSettingsAfterResolutionIsSet() {
        let activator = MockContentViewModalActivating()
        let coordinator = ContentViewModalCoordinator(activator: activator)
        let resolution = ProjectCanvasResolution(width: 1920, height: 1080)
        var state = ContentViewModalState()

        coordinator.syncModalPresentation(
            state: &state,
            requiresProjectCanvasResolutionSetup: true,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 12,
            shouldAutoPresentEmptyCutOnboarding: false,
            markEmptyCutOnboardingPresented: {}
        )
        XCTAssertNotNil(state.projectSettingsPresentation)

        coordinator.syncModalPresentation(
            state: &state,
            requiresProjectCanvasResolutionSetup: false,
            projectCanvasResolution: resolution,
            projectPlaybackFPS: 12,
            shouldAutoPresentEmptyCutOnboarding: false,
            markEmptyCutOnboardingPresented: {}
        )

        XCTAssertNil(state.projectSettingsPresentation)
    }

    func testApplyProjectSettingsUpdatesResolutionAndFPSTogether() {
        let coordinator = ContentViewModalCoordinator(activator: MockContentViewModalActivating())
        let initialResolution = ProjectCanvasResolution(width: 1920, height: 1080)
        let appliedResolution = ProjectCanvasResolution(width: 1280, height: 720)
        var state = ContentViewModalState(
            projectSettingsPresentation: ProjectSettingsPresentation(
                initialResolution: initialResolution,
                initialPlaybackFPS: 12,
                isRequired: true
            )
        )
        var appliedSettings: (ProjectCanvasResolution, Int)?

        coordinator.applyProjectSettings(
            state: &state,
            resolution: appliedResolution,
            playbackFPS: 24,
            applySettings: { resolution, playbackFPS in
                appliedSettings = (resolution, playbackFPS)
            }
        )

        XCTAssertEqual(appliedSettings?.0, appliedResolution)
        XCTAssertEqual(appliedSettings?.1, 24)
        XCTAssertNil(state.projectSettingsPresentation)
    }

    func testDismissHelpersClearModalStateAndError() {
        let coordinator = ContentViewModalCoordinator(activator: MockContentViewModalActivating())
        var state = ContentViewModalState(
            projectSettingsPresentation: ProjectSettingsPresentation(
                initialResolution: ProjectCanvasResolution(width: 1920, height: 1080),
                initialPlaybackFPS: 12,
                isRequired: false
            ),
            isCutOnboardingPresented: true
        )
        var errorMessage: String? = "Problem"

        XCTAssertTrue(coordinator.isErrorAlertPresented(errorMessage: errorMessage))

        coordinator.dismissProjectSettings(state: &state)
        coordinator.dismissEmptyCutOnboarding(state: &state)
        coordinator.dismissErrorAlert {
            errorMessage = nil
        }

        XCTAssertNil(state.projectSettingsPresentation)
        XCTAssertFalse(state.isCutOnboardingPresented)
        XCTAssertFalse(coordinator.isErrorAlertPresented(errorMessage: errorMessage))
    }
}

@MainActor
private final class MockContentViewModalActivating: ContentViewModalActivating {
    private(set) var activationCount = 0

    func activateAppForModalInput() {
        activationCount += 1
    }
}
