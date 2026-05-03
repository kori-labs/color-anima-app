import ColorAnimaAppWorkspaceApplication
import Foundation

package struct ProjectSettingsDraft: Equatable {
    package var widthText: String
    package var heightText: String
    package var fpsText: String

    package init(initialResolution: ProjectCanvasResolution, initialPlaybackFPS: Int) {
        widthText = "\(initialResolution.width)"
        heightText = "\(initialResolution.height)"
        fpsText = "\(initialPlaybackFPS)"
    }

    package var parsedResolution: ProjectCanvasResolution? {
        guard let width = Self.parsePositiveInteger(widthText),
              let height = Self.parsePositiveInteger(heightText) else {
            return nil
        }

        return ProjectCanvasResolution(width: width, height: height)
    }

    package var parsedPlaybackFPS: Int? {
        Self.parsePositiveInteger(fpsText)
    }

    private static func parsePositiveInteger(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }
}
