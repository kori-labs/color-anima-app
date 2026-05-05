import ColorAnimaAppWorkspace
import SwiftUI

/// Integrated preview: Intake screen (engine-offline path).
/// Uses the real EngineLinkGate which routes to the offline intake card when no
/// kernel binary is present (the normal state in a Design Studio build).
struct IntakeCompositeView: View {
    var body: some View {
        EngineLinkGate()
            .frame(minWidth: 640, minHeight: 480)
    }
}
