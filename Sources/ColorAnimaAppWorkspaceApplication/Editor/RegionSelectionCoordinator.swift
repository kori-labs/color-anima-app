import CoreGraphics
import Foundation

// MARK: - DTOs

/// A lightweight region descriptor used by RegionSelectionCoordinator.
/// Carries the minimum surface needed for selection, modifier, range, and
/// assignment operations without exposing kernel-internal types.
public struct RegionSelectionRegion: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    /// Normalised centroid in image-space coordinates.  Used by bounding-box
    /// range select (Shift-click).
    public var centroid: CGPoint
    public var isBackgroundCandidate: Bool
    public var assignment: RegionSelectionAssignment?

    public init(
        id: UUID = UUID(),
        centroid: CGPoint,
        isBackgroundCandidate: Bool = false,
        assignment: RegionSelectionAssignment? = nil
    ) {
        self.id = id
        self.centroid = centroid
        self.isBackgroundCandidate = isBackgroundCandidate
        self.assignment = assignment
    }
}

/// Minimal color-system assignment carried by a region.
public struct RegionSelectionAssignment: Hashable, Equatable, Sendable {
    public var groupID: UUID
    public var subsetID: UUID
    public var statusName: String

    public init(groupID: UUID, subsetID: UUID, statusName: String) {
        self.groupID = groupID
        self.subsetID = subsetID
        self.statusName = statusName
    }
}

// MARK: - State

/// Value-type selection state owned by the caller (e.g. an AppEngine model).
public struct RegionSelectionState: Equatable, Sendable {
    public var selectedRegionID: UUID?
    public var selectedRegionIDs: Set<UUID>
    public var selectedRegionAnchorID: UUID?

    public init(
        selectedRegionID: UUID? = nil,
        selectedRegionIDs: Set<UUID> = [],
        selectedRegionAnchorID: UUID? = nil
    ) {
        self.selectedRegionID = selectedRegionID
        self.selectedRegionIDs = selectedRegionIDs
        self.selectedRegionAnchorID = selectedRegionAnchorID
    }

    public static let empty = RegionSelectionState()
}

// MARK: - Coordinator

/// Public coordinator for region selection, modifier-key multi-select,
/// bounding-box range select, assignment, and deletion.
///
/// All methods operate on plain value types — no kernel imports, no Bridge
/// calls.  The coordinator is UI-free and deterministic; callers own the
/// `RegionSelectionState` and the `[RegionSelectionRegion]` array.
public enum RegionSelectionCoordinator {

    // MARK: Select — plain

    /// Plain (no modifier) single selection.  Passing `nil` or an unknown ID
    /// clears the selection.
    public static func selectRegion(
        withID regionID: UUID?,
        in regions: [RegionSelectionRegion],
        state: inout RegionSelectionState
    ) {
        let resolved = regionID.flatMap { id in
            regions.contains(where: { $0.id == id }) ? id : nil
        }

        if state.selectedRegionID == resolved,
           state.selectedRegionIDs == (resolved.map { Set([$0]) } ?? []) {
            return
        }

        state.selectedRegionID = resolved
        if let resolved {
            state.selectedRegionIDs = [resolved]
            state.selectedRegionAnchorID = resolved
        } else {
            state.selectedRegionIDs = []
            state.selectedRegionAnchorID = nil
        }
    }

    // MARK: Select — with modifiers

    /// Modifier-aware selection.  Interprets `.additive` as Cmd-click (toggle)
    /// and `.range` as Shift-click (bounding-box range from anchor).
    /// A nil or missing `regionID` clears the selection.
    public static func selectRegion(
        withID regionID: UUID?,
        modifiers: WorkspaceSelectionModifiers,
        in regions: [RegionSelectionRegion],
        state: inout RegionSelectionState
    ) {
        guard let regionID, regions.contains(where: { $0.id == regionID }) else {
            clearSelectedRegion(in: regions, state: &state)
            return
        }

        if modifiers.contains(.additive) {
            // Cmd-click: toggle individual region in/out of selection.
            if state.selectedRegionIDs.contains(regionID) {
                state.selectedRegionIDs.remove(regionID)
                state.selectedRegionID = state.selectedRegionIDs.first
                if state.selectedRegionIDs.isEmpty {
                    state.selectedRegionAnchorID = nil
                }
            } else {
                state.selectedRegionIDs.insert(regionID)
                state.selectedRegionID = regionID
                state.selectedRegionAnchorID = regionID
            }
        } else if modifiers.contains(.range), let anchorID = state.selectedRegionAnchorID {
            // Shift-click: bounding-box range select using anchor and clicked centroids.
            guard let anchorRegion = regions.first(where: { $0.id == anchorID }),
                  let clickedRegion = regions.first(where: { $0.id == regionID }) else {
                selectRegion(withID: regionID, in: regions, state: &state)
                return
            }
            let minX = min(anchorRegion.centroid.x, clickedRegion.centroid.x)
            let maxX = max(anchorRegion.centroid.x, clickedRegion.centroid.x)
            let minY = min(anchorRegion.centroid.y, clickedRegion.centroid.y)
            let maxY = max(anchorRegion.centroid.y, clickedRegion.centroid.y)
            let boxIDs = Set(
                regions
                    .filter {
                        $0.centroid.x >= minX && $0.centroid.x <= maxX &&
                        $0.centroid.y >= minY && $0.centroid.y <= maxY
                    }
                    .map(\.id)
            )
            state.selectedRegionIDs = boxIDs.union([anchorID, regionID])
            state.selectedRegionID = regionID
            // Anchor stays at the previously established anchor.
        } else {
            // Plain click through this overload: single select.
            selectRegion(withID: regionID, in: regions, state: &state)
            return
        }
    }

    // MARK: Range select (inspector Shift-click path)

    /// Explicit range selection used by inspector list Shift-click.
    /// Sets the provided `regionIDs` as the full selection and records
    /// `primaryID` as the primary and anchor.
    public static func selectRegionRange(
        _ regionIDs: Set<UUID>,
        primaryID: UUID,
        in regions: [RegionSelectionRegion],
        state: inout RegionSelectionState
    ) {
        let valid = regionIDs.filter { id in regions.contains(where: { $0.id == id }) }
        state.selectedRegionIDs = valid
        state.selectedRegionID = valid.contains(primaryID) ? primaryID : valid.first
        state.selectedRegionAnchorID = state.selectedRegionID
    }

    // MARK: Clear

    /// Clears all selection state.  No-op if already empty.
    public static func clearSelectedRegion(
        in regions: [RegionSelectionRegion],
        state: inout RegionSelectionState
    ) {
        guard state.selectedRegionID != nil || state.selectedRegionIDs.isEmpty == false else { return }
        state.selectedRegionID = nil
        state.selectedRegionIDs = []
        state.selectedRegionAnchorID = nil
    }

    // MARK: Assign

    /// Assigns the region identified by `regionID` to the given group/subset/status.
    /// Only that single region is modified regardless of the current multi-selection.
    @discardableResult
    public static func assignRegion(
        withID regionID: UUID,
        groupID: UUID,
        subsetID: UUID,
        statusName: String,
        in regions: inout [RegionSelectionRegion]
    ) -> Bool {
        guard let index = regions.firstIndex(where: { $0.id == regionID }) else { return false }
        regions[index].assignment = RegionSelectionAssignment(
            groupID: groupID,
            subsetID: subsetID,
            statusName: statusName
        )
        return true
    }

    /// Assigns the currently selected region (single-selection primary) to the
    /// given group/subset/status.
    @discardableResult
    public static func assignSelectedRegion(
        groupID: UUID,
        subsetID: UUID,
        statusName: String,
        in regions: inout [RegionSelectionRegion],
        state: RegionSelectionState
    ) -> Bool {
        guard let selectedID = state.selectedRegionID else { return false }
        return assignRegion(
            withID: selectedID,
            groupID: groupID,
            subsetID: subsetID,
            statusName: statusName,
            in: &regions
        )
    }

    /// Batch-assigns all currently selected regions to the given
    /// group/subset/status.  Uses `selectedRegionIDs` when non-empty, otherwise
    /// falls back to the single `selectedRegionID`.
    @discardableResult
    public static func batchAssignSelectedRegions(
        groupID: UUID,
        subsetID: UUID,
        statusName: String,
        in regions: inout [RegionSelectionRegion],
        state: RegionSelectionState
    ) -> Bool {
        let targetIDs = state.selectedRegionIDs.isEmpty
            ? (state.selectedRegionID.map { Set([$0]) } ?? [])
            : state.selectedRegionIDs

        guard targetIDs.isEmpty == false else { return false }

        var didAssignAny = false
        for index in regions.indices where targetIDs.contains(regions[index].id) {
            regions[index].assignment = RegionSelectionAssignment(
                groupID: groupID,
                subsetID: subsetID,
                statusName: statusName
            )
            didAssignAny = true
        }
        return didAssignAny
    }

    // MARK: Delete

    /// Removes the currently selected regions from the array and clears
    /// selection state.
    public static func deleteSelectedRegions(
        in regions: inout [RegionSelectionRegion],
        state: inout RegionSelectionState
    ) {
        let idsToDelete = state.selectedRegionIDs.isEmpty
            ? (state.selectedRegionID.map { [$0] } ?? [])
            : Array(state.selectedRegionIDs)

        guard idsToDelete.isEmpty == false else { return }

        regions.removeAll { idsToDelete.contains($0.id) }
        state.selectedRegionID = nil
        state.selectedRegionIDs = []
        state.selectedRegionAnchorID = nil
    }
}
