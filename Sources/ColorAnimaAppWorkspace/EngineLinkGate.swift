import ColorAnimaAppShell
import SwiftUI

package enum EngineLinkGateDestination: Equatable, Sendable {
    case workspaceShell
    case offlineIntake

    package static func resolve(for state: WorkspaceState) -> EngineLinkGateDestination {
        state.engineStatus.kernelLinked ? .workspaceShell : .offlineIntake
    }
}

public struct EngineLinkGate: View {
    private let model: WorkspaceModel
    @State private var state: WorkspaceState
    @State private var didRunAutoCheck = false

    public init(model: WorkspaceModel = WorkspaceModel()) {
        self.model = model
        _state = State(initialValue: model.initialState())
    }

    public var body: some View {
        Group {
            switch EngineLinkGateDestination.resolve(for: state) {
            case .workspaceShell:
                WorkspaceShellView(state: state, onRecheck: rerun)
            case .offlineIntake:
                IntakeChrome {
                    IntakeOfflineCard(state: state, onRecheck: rerun)
                }
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
