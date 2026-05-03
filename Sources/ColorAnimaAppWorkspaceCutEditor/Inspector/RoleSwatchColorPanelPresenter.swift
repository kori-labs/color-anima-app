import SwiftUI

@MainActor
package protocol RoleSwatchColorPanelPresenting: AnyObject {
    func present(selection: Binding<Color>)
    func syncVisiblePanel(selection: Binding<Color>)
}

@MainActor
package final class NoOpRoleSwatchColorPanelPresenter: RoleSwatchColorPanelPresenting {
    package static let shared = NoOpRoleSwatchColorPanelPresenter()

    package init() {}

    package func present(selection: Binding<Color>) {}

    package func syncVisiblePanel(selection: Binding<Color>) {}
}
