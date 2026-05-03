import ColorAnimaAppWorkspaceApplication
import SwiftUI

extension RGBAColor {
    package var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
