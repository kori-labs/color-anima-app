import SwiftUI
import ColorAnimaDesignStudioTokenManifest

/// Category grouping for preview entries in the gallery.
enum ComponentPreviewCategory: String, CaseIterable {
    case color = "Color"
    case spacing = "Spacing"
    case typography = "Typography"
    case cornerRadius = "Corner Radius"
    case composite = "Composite"
}

/// A single entry in the component preview registry.
/// `view` receives the current in-memory `TokenManifest` so each render
/// reflects live editor changes.
///
/// Marked `@MainActor` so the view-producing closure is safe to store in a
/// static array under Swift 6 strict concurrency.
@MainActor
struct ComponentPreviewEntry: Identifiable {
    let id: String
    let title: String
    let category: ComponentPreviewCategory
    let view: (TokenManifest) -> AnyView
}
