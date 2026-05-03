import ColorAnimaAppWorkspaceApplication

package enum RegionListAssignmentText {
    package static func string(for assignment: RegionListAssignment) -> String {
        switch assignment {
        case let .assigned(groupName: groupName, subsetName: subsetName):
            return "\(groupName) / \(subsetName)"
        case .unassigned:
            return "Unassigned"
        }
    }
}
