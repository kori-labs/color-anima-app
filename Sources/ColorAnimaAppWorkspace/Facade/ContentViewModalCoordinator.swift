import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspacePlatformMacOS
import Foundation

@MainActor
protocol ContentViewModalActivating {
    func activateAppForModalInput()
}

@MainActor
struct FilePanelsContentViewModalActivating: ContentViewModalActivating {
    func activateAppForModalInput() {
        FilePanels.activateAppForModalInput()
    }
}

@MainActor
struct ContentViewModalCoordinator {
    private let activator: any ContentViewModalActivating

    init(activator: any ContentViewModalActivating = FilePanelsContentViewModalActivating()) {
        self.activator = activator
    }

    func presentProjectSettings(
        state: inout ContentViewModalState,
        projectCanvasResolution: ProjectCanvasResolution,
        projectPlaybackFPS: Int,
        isRequired: Bool = false
    ) {
        activator.activateAppForModalInput()
        state.isCutOnboardingPresented = false
        state.projectSettingsPresentation = ProjectSettingsPresentation(
            initialResolution: projectCanvasResolution,
            initialPlaybackFPS: projectPlaybackFPS,
            isRequired: isRequired
        )
    }

    func syncModalPresentation(
        state: inout ContentViewModalState,
        requiresProjectCanvasResolutionSetup: Bool,
        projectCanvasResolution: ProjectCanvasResolution,
        projectPlaybackFPS: Int,
        shouldAutoPresentEmptyCutOnboarding: Bool,
        markEmptyCutOnboardingPresented: () -> Void
    ) {
        if requiresProjectCanvasResolutionSetup {
            state.isCutOnboardingPresented = false

            if state.projectSettingsPresentation == nil || state.projectSettingsPresentation?.isRequired == false {
                presentProjectSettings(
                    state: &state,
                    projectCanvasResolution: projectCanvasResolution,
                    projectPlaybackFPS: projectPlaybackFPS,
                    isRequired: true
                )
            }
            return
        }

        if state.projectSettingsPresentation?.isRequired == true {
            state.projectSettingsPresentation = nil
        }

        guard shouldAutoPresentEmptyCutOnboarding,
              state.projectSettingsPresentation == nil,
              state.isCutOnboardingPresented == false else {
            return
        }

        markEmptyCutOnboardingPresented()
        state.isCutOnboardingPresented = true
    }

    func applyProjectSettings(
        state: inout ContentViewModalState,
        resolution: ProjectCanvasResolution,
        playbackFPS: Int,
        applySettings: (ProjectCanvasResolution, Int) -> Void
    ) {
        applySettings(resolution, playbackFPS)
        state.projectSettingsPresentation = nil
    }

    func dismissProjectSettings(state: inout ContentViewModalState) {
        state.projectSettingsPresentation = nil
    }

    func dismissEmptyCutOnboarding(state: inout ContentViewModalState) {
        state.isCutOnboardingPresented = false
    }

    func isErrorAlertPresented(errorMessage: String?) -> Bool {
        errorMessage != nil
    }

    func dismissErrorAlert(clearError: () -> Void) {
        clearError()
    }
}
