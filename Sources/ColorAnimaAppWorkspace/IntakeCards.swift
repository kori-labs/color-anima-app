import ColorAnimaAppShell
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

/// Shared chrome: header (displayName + role), content slot, footer status line.
package struct IntakeChrome<Content: View>: View {
    private let content: Content

    package init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppShellMetadata.displayName)
                    // TODO: design-system Phase 0 follow-up — no display-size token yet (30pt semibold)
                    .font(.system(size: 30, weight: .semibold))
                Text(AppShellMetadata.repositoryRole)
                    .font(WorkspaceFoundation.Typography.secondaryLabel)
                    .foregroundStyle(.secondary)
            }

            Divider()

            content

            Spacer(minLength: 0)

            Text(AppShellMetadata.statusLine)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)
        }
        // TODO(design-system): off-grid 28pt padding; consider adding Metrics.space7=28 in a Phase 0 follow-up.
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Engine offline intake card: red seal + Stage Kernel CTA + Re-check.
package struct IntakeOfflineCard: View {
    let state: WorkspaceState
    let onRecheck: () -> Void
    @State private var showStageInstructions = false

    package init(state: WorkspaceState, onRecheck: @escaping () -> Void) {
        self.state = state
        self.onRecheck = onRecheck
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(state.engineStatus.title, systemImage: "xmark.seal")
                .font(WorkspaceFoundation.Typography.primaryLabel)
                .fontWeight(.medium)
                .foregroundStyle(.red)

            Text("Stage the kernel binary to enable workspace activation.")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(.primary)

            Text(state.engineStatus.detail)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    onRecheck()
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    showStageInstructions = true
                } label: {
                    Label("Stage Kernel", systemImage: "shippingbox")
                }
                .buttonStyle(.borderedProminent)
            }

            Text(state.checkDetail)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .alert("Stage Kernel Binary", isPresented: $showStageInstructions) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                """
                Run from the repository root:

                bash scripts/dev-bootstrap.sh
                export COLOR_ANIMA_KERNEL_PATH=".local-core/ColorAnimaKernel.xcframework"
                """
            )
        }
    }
}

/// Engine linked but workspace activation pending kernel adapter rollout.
package struct IntakeAdapterPendingCard: View {
    let state: WorkspaceState
    let onRecheck: () -> Void

    package init(state: WorkspaceState, onRecheck: @escaping () -> Void) {
        self.state = state
        self.onRecheck = onRecheck
    }

    private var versionString: String {
        state.engineStatus.kernelVersion?.description ?? "unknown"
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Engine linked (kernel v\(versionString))", systemImage: "checkmark.seal")
                .font(WorkspaceFoundation.Typography.primaryLabel)
                .fontWeight(.medium)
                .foregroundStyle(.green)

            Text(
                "Workspace UI activation pending kernel adapter rollout. See AGENTS.md → Adapter rollout dependency."
            )
            .font(WorkspaceFoundation.Typography.secondaryLabel)
            .foregroundStyle(.primary)

            Text(state.engineStatus.detail)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    onRecheck()
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            Text(state.checkDetail)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

