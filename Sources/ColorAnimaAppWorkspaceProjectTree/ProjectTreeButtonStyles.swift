import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

typealias SidebarChromeButtonStyle = ChromeButtonStyle

extension View {
    func sidebarCardChrome(fill: Color, stroke: Color, cornerRadius: CGFloat) -> some View {
        chromeCard(fill: fill, stroke: stroke, cornerRadius: cornerRadius)
    }

    func sidebarInteractiveRowChrome(isActive: Bool, cornerRadius: CGFloat) -> some View {
        chromeInteractiveRow(isActive: isActive, cornerRadius: cornerRadius)
    }
}
