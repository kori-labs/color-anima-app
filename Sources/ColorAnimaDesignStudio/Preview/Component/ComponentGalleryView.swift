import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaDesignStudioPreview
import ColorAnimaAppWorkspaceDesignSystem

/// Main preview pane. Renders the `ComponentPreviewRegistry` as a vertically
/// scrolling gallery, grouped by category, against the live in-memory manifest.
///
/// Because `StudioModel` is `@Observable`, SwiftUI will re-render this view
/// (and all cells) whenever the editor updates any token — no refresh button needed.
struct ComponentGalleryView: View {
    let model: StudioModel

    private var manifest: TokenManifest {
        TokenManifest(
            schemaVersion: 1,
            extractedAt: "",
            colors: model.colors,
            spacing: model.spacing,
            typography: model.typography,
            cornerRadii: model.cornerRadii
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space4) {
                ForEach(ComponentPreviewCategory.allCases, id: \.rawValue) { category in
                    let entries = ComponentPreviewRegistry.entries.filter { $0.category == category }
                    if !entries.isEmpty {
                        categorySectionView(category: category, entries: entries)
                    }
                }
            }
            .padding(WorkspaceFoundation.Metrics.space4)
        }
        .background(WorkspaceFoundation.Surface.canvas)
    }

    @ViewBuilder
    private func categorySectionView(
        category: ComponentPreviewCategory,
        entries: [ComponentPreviewEntry]
    ) -> some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2) {
            Text(category.rawValue)
                .font(WorkspaceFoundation.Typography.sectionHeader)
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                .padding(.bottom, WorkspaceFoundation.Metrics.microSpace0_5)

            Divider()
                .foregroundStyle(WorkspaceFoundation.Stroke.divider)

            ForEach(entries) { entry in
                GalleryEntryWrapper(entry: entry, manifest: manifest)
            }
        }
    }
}

// MARK: - Per-entry wrapper

/// Wraps a single preview entry, displaying its title and rendered view.
private struct GalleryEntryWrapper: View {
    let entry: ComponentPreviewEntry
    let manifest: TokenManifest

    var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space1) {
            Text(entry.title)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)

            entry.view(manifest)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WorkspaceFoundation.Metrics.space3)
                .background(WorkspaceFoundation.Surface.raised)
                .clipShape(RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.rowCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.rowCornerRadius)
                        .stroke(WorkspaceFoundation.Stroke.divider, lineWidth: 1)
                )
        }
    }
}
