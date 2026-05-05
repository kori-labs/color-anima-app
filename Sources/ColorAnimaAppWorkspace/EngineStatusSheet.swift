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
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space5) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppShellMetadata.displayName)
                    .font(WorkspaceFoundation.Typography.displayCardTitle)
                    .tracking(WorkspaceFoundation.Typography.displayCardTitleTracking)
                Text(AppShellMetadata.repositoryRole)
                    .font(WorkspaceFoundation.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .top, spacing: WorkspaceFoundation.Metrics.space4) {
                VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2) {
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

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: WorkspaceFoundation.Metrics.space2_5) {
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
        .padding(WorkspaceFoundation.Metrics.space7)
        .frame(minWidth: 520, minHeight: 420)
    }
}
