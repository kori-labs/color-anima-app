import Observation
import ColorAnimaDesignStudioTokenManifest

/// Categories displayed in the studio sidebar.
enum TokenCategory: String, CaseIterable, Identifiable {
    case colors = "Colors"
    case spacing = "Spacing"
    case typography = "Typography"
    case cornerRadii = "Corner Radii"

    var id: String { rawValue }
}

/// Central model for the Design Studio. Loads the bundled manifest at startup
/// and holds a mutable in-memory copy. Write-back is wired in Wave 3b (Child 5).
@Observable
final class StudioModel {

    // MARK: - Manifest data (mutable in-memory copies)

    var colors: [ColorToken]
    var spacing: [SpacingToken]
    var typography: [TypographyToken]
    var cornerRadii: [CornerRadiusToken]

    // MARK: - UI state

    var selectedCategory: TokenCategory = .colors
    var isDirty: Bool = false
    var loadError: String?

    // MARK: - Init

    init() {
        // Optimistic defaults; will be populated in load()
        colors = []
        spacing = []
        typography = []
        cornerRadii = []
        load()
    }

    // MARK: - Load

    private func load() {
        do {
            let manifest = try TokenManifestLoader.bundled()
            colors = manifest.colors
            spacing = manifest.spacing
            typography = manifest.typography
            cornerRadii = manifest.cornerRadii
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Mutation helpers (set dirty; write-back wired in Child 5)

    func updateColor(_ token: ColorToken, at index: Int) {
        guard index < colors.count else { return }
        colors[index] = token
        isDirty = true
    }

    func updateSpacing(_ token: SpacingToken, at index: Int) {
        guard index < spacing.count else { return }
        spacing[index] = token
        isDirty = true
    }

    func updateTypography(_ token: TypographyToken, at index: Int) {
        guard index < typography.count else { return }
        typography[index] = token
        isDirty = true
    }

    func updateCornerRadius(_ token: CornerRadiusToken, at index: Int) {
        guard index < cornerRadii.count else { return }
        cornerRadii[index] = token
        isDirty = true
    }
}
