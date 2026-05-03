import SwiftUI

package enum RoleSwatchKind: String, CaseIterable, Sendable {
    case base
    case highlight
    case shadow
}

package struct RoleSwatchInteractionState {
    let selection: Binding<Color>?
    let isSelected: Bool

    package var isEditable: Bool {
        selection != nil
    }

    package var strokeLineWidth: CGFloat {
        isSelected ? 2 : 1
    }

    package var shadowOpacity: Double {
        0
    }

    package var labelWeight: Font.Weight {
        isSelected ? .semibold : .regular
    }

    package init(selection: Binding<Color>?, isSelected: Bool = false) {
        self.selection = selection
        self.isSelected = isSelected
    }
}
