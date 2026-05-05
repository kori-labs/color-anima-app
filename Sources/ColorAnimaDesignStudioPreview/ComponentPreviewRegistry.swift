import SwiftUI
import ColorAnimaDesignStudioTokenManifest

// MARK: - Coverage constant
//
// Hand-curated list of all chrome primitive IDs that must appear in `entries`.
// Source files and approximate line ranges:
//   - Sources/ColorAnimaAppWorkspaceDesignSystem/ChromePrimitives.swift
//       L3-38:   ChromeButtonStyle (ButtonStyle)
//       L87-115: chromeCard, chromeInteractiveRow, chromeSelectablePanelCard (View modifiers)
//   - Sources/ColorAnimaAppWorkspaceDesignSystem/HoverDeleteConfirmButton.swift
//       L3-74:   HoverDeleteConfirmButton (standalone View)
//   - Sources/ColorAnimaAppWorkspaceDesignSystem/InlineRenameField.swift
//       L4-75:   InlineRenameField (standalone View)
//
// Update this list whenever a new public chrome primitive is added to the above files.
public let expectedPrimitiveIDs: [String] = [
    "primitive.ChromeButtonStyle",
    "primitive.chromeCard",
    "primitive.chromeInteractiveRow",
    "primitive.chromeSelectablePanelCard",
    "primitive.HoverDeleteConfirmButton",
    "primitive.InlineRenameField",
]

/// Seed registry for the live component preview gallery.
///
/// Append entries here without restructuring.
/// All chrome primitives defined in `ChromePrimitives.swift`,
/// `HoverDeleteConfirmButton.swift`, and `InlineRenameField.swift` are enrolled
/// under `.primitive` (added in Child 6 / Wave 5).
@MainActor
public struct ComponentPreviewRegistry {
    public static let entries: [ComponentPreviewEntry] = [
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

        // MARK: Primitive — ChromeButtonStyle
        // Source: Sources/ColorAnimaAppWorkspaceDesignSystem/ChromePrimitives.swift L3-38
        ComponentPreviewEntry(
            id: "primitive.ChromeButtonStyle",
            title: "ChromeButtonStyle",
            category: .primitive,
            view: { _ in AnyView(ChromeButtonStyleCell()) }
        ),

        // MARK: Primitive — chromeCard modifier
        // Source: Sources/ColorAnimaAppWorkspaceDesignSystem/ChromePrimitives.swift L88-95
        ComponentPreviewEntry(
            id: "primitive.chromeCard",
            title: "chromeCard",
            category: .primitive,
            view: { _ in AnyView(ChromeCardModifierCell()) }
        ),

        // MARK: Primitive — chromeInteractiveRow modifier
        // Source: Sources/ColorAnimaAppWorkspaceDesignSystem/ChromePrimitives.swift L98-104
        ComponentPreviewEntry(
            id: "primitive.chromeInteractiveRow",
            title: "chromeInteractiveRow",
            category: .primitive,
            view: { _ in AnyView(ChromeInteractiveRowModifierCell()) }
        ),

        // MARK: Primitive — chromeSelectablePanelCard modifier
        // Source: Sources/ColorAnimaAppWorkspaceDesignSystem/ChromePrimitives.swift L107-113
        ComponentPreviewEntry(
            id: "primitive.chromeSelectablePanelCard",
            title: "chromeSelectablePanelCard",
            category: .primitive,
            view: { _ in AnyView(ChromeSelectablePanelCardCell()) }
        ),

        // MARK: Primitive — HoverDeleteConfirmButton
        // Source: Sources/ColorAnimaAppWorkspaceDesignSystem/HoverDeleteConfirmButton.swift L3-74
        ComponentPreviewEntry(
            id: "primitive.HoverDeleteConfirmButton",
            title: "HoverDeleteConfirmButton",
            category: .primitive,
            view: { _ in AnyView(HoverDeleteConfirmButtonCell()) }
        ),

        // MARK: Primitive — InlineRenameField
        // Source: Sources/ColorAnimaAppWorkspaceDesignSystem/InlineRenameField.swift L4-75
        ComponentPreviewEntry(
            id: "primitive.InlineRenameField",
            title: "InlineRenameField",
            category: .primitive,
            view: { _ in AnyView(InlineRenameFieldCell()) }
        ),
    ]
}
