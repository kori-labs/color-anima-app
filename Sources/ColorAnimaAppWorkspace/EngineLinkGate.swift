import ColorAnimaAppShell
import SwiftUI

public struct EngineLinkGate: View {
    private let model: WorkspaceModel
    @State private var state: WorkspaceState
    @State private var didRunAutoCheck = false

    public init(model: WorkspaceModel = WorkspaceModel()) {
        self.model = model
        _state = State(initialValue: model.initialState())
    }

    public var body: some View {
        IntakeChrome {
            if state.engineStatus.kernelLinked {
                IntakeAdapterPendingCard(state: state, onRecheck: rerun)
            } else {
                IntakeOfflineCard(state: state, onRecheck: rerun)
            }
        }
        .onAppear {
            guard !didRunAutoCheck else { return }
            didRunAutoCheck = true
            rerun()
        }
    }

    private func rerun() {
        state = model.runStartupCheck()
    }
}
