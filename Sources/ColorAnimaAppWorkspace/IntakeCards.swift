import ColorAnimaAppShell
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
                    .font(.system(size: 30, weight: .semibold))
                Text(AppShellMetadata.repositoryRole)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Divider()

            content

            Spacer(minLength: 0)

            Text(AppShellMetadata.statusLine)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.red)

            Text("Stage the kernel binary to enable workspace activation.")
                .font(.system(size: 14))
                .foregroundStyle(.primary)

            Text(state.engineStatus.detail)
                .font(.system(size: 13))
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
                .font(.system(size: 12))
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.green)

            Text(
                "Workspace UI activation pending kernel adapter rollout. See AGENTS.md → Adapter rollout dependency."
            )
            .font(.system(size: 14))
            .foregroundStyle(.primary)

            Text(state.engineStatus.detail)
                .font(.system(size: 13))
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
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

