import SwiftUI
import ColorAnimaDesignStudioTokenManifest

/// Category grouping for preview entries in the gallery.
public enum ComponentPreviewCategory: String, CaseIterable {
    case color = "Color"
    case spacing = "Spacing"
    case typography = "Typography"
    case cornerRadius = "Corner Radius"
    case primitive = "Primitive"
    case composite = "Composite"
}

/// A single entry in the component preview registry.
/// `view` receives the current in-memory `TokenManifest` so each render
/// reflects live editor changes.
///
/// Marked `@MainActor` so the view-producing closure is safe to store in a
/// static array under Swift 6 strict concurrency.
@MainActor
public struct ComponentPreviewEntry: Identifiable {
    public let id: String
    public let title: String
    public let category: ComponentPreviewCategory
    public let view: (TokenManifest) -> AnyView

    public init(
        id: String,
        title: String,
        category: ComponentPreviewCategory,
        view: @escaping (TokenManifest) -> AnyView
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.view = view
    }
}
