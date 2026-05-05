import ColorAnimaAppShell
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

public struct EngineStatusSheet: View {
    @Binding private var isPresented: Bool
    private let model: WorkspaceModel
    @State private var state: WorkspaceState

    public init(isPresented: Binding<Bool>, model: WorkspaceModel = WorkspaceModel()) {
        _isPresented = isPresented
        self.model = model
        _state = State(initialValue: model.runStartupCheck())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppShellMetadata.displayName)
                    // TODO: design-system Phase 0 follow-up — no display-size token yet (24pt semibold)
                    .font(.system(size: 24, weight: .semibold))
                Text(AppShellMetadata.repositoryRole)
                    .font(WorkspaceFoundation.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        state.engineStatus.title,
                        systemImage: state.engineStatus.kernelLinked ? "checkmark.seal" : "xmark.seal"
                    )
                    .font(WorkspaceFoundation.Typography.sectionHeader)
                    Text(state.engineStatus.detail)
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Button {
                    state = model.runStartupCheck()
                } label: {
                    Label("Check", systemImage: "bolt.horizontal")
                }
                .buttonStyle(.borderedProminent)
            }

            Text(state.checkDetail)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                ForEach(state.operationalSurfaces, id: \.name) { surface in
                    GridRow {
                        Text(surface.name)
                            .font(WorkspaceFoundation.Typography.sectionHeader)
                        Text(surface.state)
                            .font(WorkspaceFoundation.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(AppShellMetadata.statusLine)
                .font(WorkspaceFoundation.Typography.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(WorkspaceFoundation.Metrics.space6) // was 28pt; snapped to space6=24pt (nearest grid step)
        .frame(minWidth: 520, minHeight: 420)
    }
}
