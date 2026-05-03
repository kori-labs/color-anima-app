public enum RegionListAssignment: Equatable, Hashable, Sendable {
    case assigned(groupName: String, subsetName: String)
    case unassigned
}
