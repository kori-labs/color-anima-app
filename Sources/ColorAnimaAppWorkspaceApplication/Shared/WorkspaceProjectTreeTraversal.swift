import Foundation

public extension WorkspaceProjectTreeNode {
    var firstCutID: UUID? {
        if kind == .cut {
            return id
        }
        for child in children {
            if let cutID = child.firstCutID {
                return cutID
            }
        }
        return nil
    }

    var allCutIDs: [UUID] {
        var ids: [UUID] = kind == .cut ? [id] : []
        for child in children {
            ids.append(contentsOf: child.allCutIDs)
        }
        return ids
    }
}
