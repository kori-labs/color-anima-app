import Foundation

/// Per-cut reference-frame tracking state for the session layer.
///
/// Holds which frames are designated as reference frames for a given cut,
/// which one is the active (preferred) reference, and a flag indicating that
/// a new reference frame was added to a cut that already has tracking history
///
/// Scope: ACTION INPUT / STATE TRANSITION only.
public struct ProjectReferenceFrameActionsState: Hashable, Equatable, Sendable {
    /// ID of the cut currently open in the editor.
    public var activeCutID: UUID?
    /// Reference-frame ID sets keyed by cut ID.
    public var keyFrameIDsByCutID: [UUID: Set<UUID>]
    /// Active (preferred) reference-frame ID keyed by cut ID.
    public var activeReferenceFrameIDByCutID: [UUID: UUID]
    /// Indicates that an `addReferenceFrame` mutation was applied to a cut
    /// whether to run scoped region update.
    public var needsRegionRewrite: Bool
    /// Informational: the frame ID that triggered `needsRegionRewrite`.
    public var regionRewriteTriggerFrameID: UUID?
    /// Dirty flag set on any mutating action; callers use this to decide
    /// whether to persist the project.
    public var isDirty: Bool

    public init(
        activeCutID: UUID? = nil,
        keyFrameIDsByCutID: [UUID: Set<UUID>] = [:],
        activeReferenceFrameIDByCutID: [UUID: UUID] = [:],
        needsRegionRewrite: Bool = false,
        regionRewriteTriggerFrameID: UUID? = nil,
        isDirty: Bool = false
    ) {
        self.activeCutID = activeCutID
        self.keyFrameIDsByCutID = keyFrameIDsByCutID
        self.activeReferenceFrameIDByCutID = activeReferenceFrameIDByCutID
        self.needsRegionRewrite = needsRegionRewrite
        self.regionRewriteTriggerFrameID = regionRewriteTriggerFrameID
        self.isDirty = isDirty
    }
}

// MARK: - ProjectSessionCoordinator + ReferenceFrameActions

extension ProjectSessionCoordinator {

    /// Sets `frameID` as the sole reference frame for the active cut,
    /// replacing any existing reference-frame set.
    ///
    /// No-ops when there is no active cut or `frameID` is not among the
    /// provided `knownFrameIDs` for that cut.
    public static func setReferenceFrame(
        _ frameID: UUID,
        knownFrameIDs: Set<UUID>,
        in state: inout ProjectReferenceFrameActionsState
    ) {
        guard let activeCutID = state.activeCutID,
              knownFrameIDs.contains(frameID) else {
            return
        }

        state.keyFrameIDsByCutID[activeCutID] = [frameID]
        state.isDirty = true
        state.needsRegionRewrite = false
        state.regionRewriteTriggerFrameID = nil
    }

    /// Adds `frameID` to the reference-frame set of the active cut.
    ///
    /// No-ops when there is no active cut or `frameID` is not among
    /// `knownFrameIDs`. Sets `needsRegionRewrite` when the cut already
    /// has tracking history (`cutHasTrackingHistory == true`) and `frameID`
    /// is genuinely new to the reference set.
    public static func addReferenceFrame(
        _ frameID: UUID,
        knownFrameIDs: Set<UUID>,
        cutHasTrackingHistory: Bool,
        in state: inout ProjectReferenceFrameActionsState
    ) {
        guard let activeCutID = state.activeCutID,
              knownFrameIDs.contains(frameID) else {
            return
        }

        let priorReferenceFrameIDs = state.keyFrameIDsByCutID[activeCutID] ?? []
        let isNewReference = priorReferenceFrameIDs.contains(frameID) == false

        var updated = priorReferenceFrameIDs
        updated.insert(frameID)
        state.keyFrameIDsByCutID[activeCutID] = updated
        state.isDirty = true

        if cutHasTrackingHistory, isNewReference {
            state.needsRegionRewrite = true
            state.regionRewriteTriggerFrameID = frameID
        } else {
            state.needsRegionRewrite = false
            state.regionRewriteTriggerFrameID = nil
        }
    }

    /// Removes `frameID` from the reference-frame set of the active cut.
    ///
    /// No-ops when there is no active cut or `frameID` is not currently a
    /// reference frame for that cut. Clears the active reference frame if it
    /// was the removed frame (callers may set a new active reference via
    /// `setActiveReferenceFrame` afterward).
    public static func removeReferenceFrame(
        _ frameID: UUID,
        in state: inout ProjectReferenceFrameActionsState
    ) {
        guard let activeCutID = state.activeCutID,
              state.keyFrameIDsByCutID[activeCutID]?.contains(frameID) == true else {
            return
        }

        state.keyFrameIDsByCutID[activeCutID]?.remove(frameID)
        state.isDirty = true
        state.needsRegionRewrite = false
        state.regionRewriteTriggerFrameID = nil

        if state.activeReferenceFrameIDByCutID[activeCutID] == frameID {
            state.activeReferenceFrameIDByCutID.removeValue(forKey: activeCutID)
        }
    }

    /// Sets `frameID` as the active (preferred) reference frame for the
    /// active cut.
    ///
    /// No-ops when there is no active cut or `frameID` is not in the
    /// reference-frame set for that cut.
    public static func setActiveReferenceFrame(
        _ frameID: UUID,
        in state: inout ProjectReferenceFrameActionsState
    ) {
        guard let activeCutID = state.activeCutID,
              state.keyFrameIDsByCutID[activeCutID]?.contains(frameID) == true else {
            return
        }

        state.activeReferenceFrameIDByCutID[activeCutID] = frameID
        state.isDirty = true
    }

    /// Clears the `needsRegionRewrite` flag and its associated trigger
    public static func clearRegionRewriteRequest(
        in state: inout ProjectReferenceFrameActionsState
    ) {
        state.needsRegionRewrite = false
        state.regionRewriteTriggerFrameID = nil
    }

    // MARK: - Read helpers

    /// Returns the current reference-frame IDs for the active cut, or an
    /// empty set when no cut is active.
    public static func keyFrameIDs(
        in state: ProjectReferenceFrameActionsState
    ) -> Set<UUID> {
        guard let activeCutID = state.activeCutID else { return [] }
        return state.keyFrameIDsByCutID[activeCutID] ?? []
    }

    /// Returns the active reference-frame ID for the active cut, or `nil`
    /// when none is set.
    public static func activeReferenceFrameID(
        in state: ProjectReferenceFrameActionsState
    ) -> UUID? {
        guard let activeCutID = state.activeCutID else { return nil }
        return state.activeReferenceFrameIDByCutID[activeCutID]
    }
}
