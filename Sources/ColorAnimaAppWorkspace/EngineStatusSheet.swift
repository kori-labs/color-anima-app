import ColorAnimaAppShell
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
                    .font(.system(size: 24, weight: .semibold))
                Text(AppShellMetadata.repositoryRole)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        state.engineStatus.title,
                        systemImage: state.engineStatus.kernelLinked ? "checkmark.seal" : "xmark.seal"
                    )
                    .font(.system(size: 15, weight: .medium))
                    Text(state.engineStatus.detail)
                        .font(.system(size: 13))
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
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                ForEach(state.operationalSurfaces, id: \.name) { surface in
                    GridRow {
                        Text(surface.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(surface.state)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(AppShellMetadata.statusLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 520, minHeight: 420)
    }
}
