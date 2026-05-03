// PreviewState.swift
// Layer: ColorAnimaAppWorkspaceApplication — public app-side preview state DTO.
//
// Replaces the deleted CutWorkspacePreviewState (source-only, imported the
// kernel-internal implementation target). All kernel-internal buffer types are replaced with
// opaque Data carriers; pixel maps use public UUID-keyed dictionaries.
//
// This struct intentionally carries no CGImage references — image handles are
// platform types and are stored by the coordinator's call site, not here.

import Foundation

/// State bag for preview rebuild tracking across an editor session.
///
/// Stores dirty flags and computed-state indicators so the coordinator can
/// decide whether a full rebuild or incremental repaint is needed.
/// The struct is value-typed and Sendable; it may be embedded in any
/// @Observable class or actor without additional synchronization.
public struct PreviewState: Equatable, Sendable {

    // MARK: - Computed flags

    /// Whether the overlay image has been computed for the current frame.
    public var overlayImageComputed: Bool

    /// Whether the line preview images (highlight / shadow guides) are dirty
    /// and need recomputation.
    public var linePreviewImagesDirty: Bool

    // MARK: - Highlight pixel maps

    /// Fill pixel indices per region for the highlight guide.
    public var highlightFillPixelsByRegionID: [UUID: [Int]]
    /// Guide pixel indices per region for the highlight guide.
    public var highlightGuidePixelsByRegionID: [UUID: [Int]]
    /// Family pixel indices per region for the highlight guide.
    public var highlightFamilyPixelsByRegionID: [UUID: [Int]]
    /// Fill opacity per region for the highlight guide.
    public var highlightFillOpacityByRegionID: [UUID: Double]

    // MARK: - Shadow pixel maps

    /// Fill pixel indices per region for the shadow guide.
    public var shadowFillPixelsByRegionID: [UUID: [Int]]
    /// Guide pixel indices per region for the shadow guide.
    public var shadowGuidePixelsByRegionID: [UUID: [Int]]
    /// Family pixel indices per region for the shadow guide.
    public var shadowFamilyPixelsByRegionID: [UUID: [Int]]
    /// Fill opacity per region for the shadow guide.
    public var shadowFillOpacityByRegionID: [UUID: Double]

    // MARK: - Init

    public init(
        overlayImageComputed: Bool = false,
        linePreviewImagesDirty: Bool = true,
        highlightFillPixelsByRegionID: [UUID: [Int]] = [:],
        highlightGuidePixelsByRegionID: [UUID: [Int]] = [:],
        highlightFamilyPixelsByRegionID: [UUID: [Int]] = [:],
        highlightFillOpacityByRegionID: [UUID: Double] = [:],
        shadowFillPixelsByRegionID: [UUID: [Int]] = [:],
        shadowGuidePixelsByRegionID: [UUID: [Int]] = [:],
        shadowFamilyPixelsByRegionID: [UUID: [Int]] = [:],
        shadowFillOpacityByRegionID: [UUID: Double] = [:]
    ) {
        self.overlayImageComputed = overlayImageComputed
        self.linePreviewImagesDirty = linePreviewImagesDirty
        self.highlightFillPixelsByRegionID = highlightFillPixelsByRegionID
        self.highlightGuidePixelsByRegionID = highlightGuidePixelsByRegionID
        self.highlightFamilyPixelsByRegionID = highlightFamilyPixelsByRegionID
        self.highlightFillOpacityByRegionID = highlightFillOpacityByRegionID
        self.shadowFillPixelsByRegionID = shadowFillPixelsByRegionID
        self.shadowGuidePixelsByRegionID = shadowGuidePixelsByRegionID
        self.shadowFamilyPixelsByRegionID = shadowFamilyPixelsByRegionID
        self.shadowFillOpacityByRegionID = shadowFillOpacityByRegionID
    }

    // MARK: - Mutation helpers

    /// Resets all computed preview fields to their initial dirty state.
    public mutating func resetCachedPreviews() {
        overlayImageComputed = false
        linePreviewImagesDirty = true
    }

    /// Resets all guide-fill pixel maps and marks line previews dirty.
    public mutating func resetGuideFillMaps() {
        highlightFillPixelsByRegionID = [:]
        shadowFillPixelsByRegionID = [:]
        highlightGuidePixelsByRegionID = [:]
        shadowGuidePixelsByRegionID = [:]
        highlightFamilyPixelsByRegionID = [:]
        shadowFamilyPixelsByRegionID = [:]
        highlightFillOpacityByRegionID = [:]
        shadowFillOpacityByRegionID = [:]
        linePreviewImagesDirty = true
    }

    /// Marks the line preview images dirty.
    public mutating func markLinePreviewImagesDirty() {
        linePreviewImagesDirty = true
    }
}
