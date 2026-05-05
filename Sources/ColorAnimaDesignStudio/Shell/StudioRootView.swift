import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Three-pane root: sidebar | editor panel | preview placeholder.
struct StudioRootView: View {
    @Bindable var model: StudioModel

    var body: some View {
        NavigationSplitView {
            StudioSidebar(selectedSection: $model.selectedSection)
        } content: {
            StudioEditorPanel(model: model)
        } detail: {
            ComponentGalleryView(model: model)
        }
        .background(WorkspaceFoundation.Surface.canvas)
        // MARK: - Banners (top overlay, stacked)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                if let errorMessage = model.loadError {
                    BannerView(
                        message: "Failed to load tokens: \(errorMessage)",
                        isError: true,
                        onDismiss: nil
                    )
                }
                if let bannerMessage = model.applyBannerMessage {
                    BannerView(
                        message: bannerMessage,
                        isError: model.applyBannerIsError,
                        onDismiss: { model.dismissApplyBanner() }
                    )
                }
                if model.externalChangeDetected {
                    BannerView(
                        message: "External change detected — discard local edits to reload?",
                        isError: false,
                        actionLabel: "Reload",
                        onAction: { model.discardAndReloadFromExternal() },
                        onDismiss: { model.dismissExternalChangeBanner() }
                    )
                }
            }
        }
        // MARK: - Toolbar
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Apply") {
                    model.applyToSource()
                }
                .disabled(!model.applyAvailable || !model.isDirty)
                .help(
                    model.applyAvailable
                        ? "Write token changes back to design-system source files"
                        : "Source repo root not found — Apply unavailable in this build"
                )
            }
            if model.isDirty {
                ToolbarItem(placement: .status) {
                    Text("Unsaved changes")
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                }
            }
        }
    }
}

// MARK: - BannerView

private struct BannerView: View {
    let message: String
    let isError: Bool
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space2) {
            Text(message)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(
                    isError
                        ? WorkspaceFoundation.Foreground.destructiveForeground
                        : WorkspaceFoundation.Foreground.primaryLabel
                )
            Spacer()
            if let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
                    .font(WorkspaceFoundation.Typography.caption)
                    .buttonStyle(.borderless)
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(WorkspaceFoundation.Typography.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
            }
        }
        .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
        .padding(.vertical, WorkspaceFoundation.Metrics.space2)
        .background(WorkspaceFoundation.Surface.raised)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
