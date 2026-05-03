import ColorAnimaAppWorkspaceApplication
import Foundation

struct ProjectSettingsPresentation: Identifiable, Equatable {
    let id = UUID()
    let initialResolution: ProjectCanvasResolution
    let initialPlaybackFPS: Int
    let isRequired: Bool

    static func == (lhs: ProjectSettingsPresentation, rhs: ProjectSettingsPresentation) -> Bool {
        lhs.initialResolution == rhs.initialResolution &&
            lhs.initialPlaybackFPS == rhs.initialPlaybackFPS &&
            lhs.isRequired == rhs.isRequired
    }
}

struct ContentViewModalState: Equatable {
    var projectSettingsPresentation: ProjectSettingsPresentation?
    var isCutOnboardingPresented = false

    var hasPresentedModal: Bool {
        projectSettingsPresentation != nil || isCutOnboardingPresented
    }
}
