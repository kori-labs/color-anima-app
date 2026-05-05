import SwiftUI
import ColorAnimaDesignStudioTokenManifest

/// Seed registry for the live component preview gallery.
///
/// This list is intentionally representative — full chrome-primitive enrollment
/// is deferred to Child 6 (Wave 5). Append entries here without restructuring.
@MainActor
struct ComponentPreviewRegistry {
    static let entries: [ComponentPreviewEntry] = [
        // MARK: Color seeds
        ComponentPreviewEntry(
            id: "color.surface.workspaceBackground",
            title: "Surface · workspaceBackground",
            category: .color,
            view: { manifest in AnyView(ColorSwatchCell(tokenName: "WorkspaceFoundation.Surface.canvas", manifest: manifest)) }
        ),
        ComponentPreviewEntry(
            id: "color.stroke.divider",
            title: "Stroke · divider",
            category: .color,
            view: { manifest in AnyView(ColorSwatchCell(tokenName: "WorkspaceFoundation.Stroke.divider", manifest: manifest)) }
        ),
        ComponentPreviewEntry(
            id: "color.surface.raised",
            title: "Surface · raised",
            category: .color,
            view: { manifest in AnyView(ColorSwatchCell(tokenName: "WorkspaceFoundation.Surface.raised", manifest: manifest)) }
        ),

        // MARK: Spacing seeds
        ComponentPreviewEntry(
            id: "spacing.s8",
            title: "Spacing · space2 (8 pt)",
            category: .spacing,
            view: { manifest in AnyView(SpacingScaleCell(tokenName: "WorkspaceFoundation.Metrics.space2", manifest: manifest)) }
        ),
        ComponentPreviewEntry(
            id: "spacing.s16",
            title: "Spacing · space4 (16 pt)",
            category: .spacing,
            view: { manifest in AnyView(SpacingScaleCell(tokenName: "WorkspaceFoundation.Metrics.space4", manifest: manifest)) }
        ),

        // MARK: Typography seed
        ComponentPreviewEntry(
            id: "typography.body",
            title: "Typography · body",
            category: .typography,
            view: { manifest in AnyView(TypographySampleCell(tokenName: "WorkspaceFoundation.Typography.primaryLabel", manifest: manifest)) }
        ),

        // MARK: Corner radius seed
        ComponentPreviewEntry(
            id: "cornerRadius.card",
            title: "Corner Radius · card (14 pt)",
            category: .cornerRadius,
            view: { manifest in AnyView(CornerRadiusSampleCell(tokenName: "WorkspaceFoundation.Metrics.cardCornerRadius", manifest: manifest)) }
        ),
    ]
}
