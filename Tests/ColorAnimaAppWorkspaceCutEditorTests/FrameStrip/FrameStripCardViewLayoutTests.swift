import AppKit
import SwiftUI
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

@MainActor
final class FrameStripCardViewLayoutTests: XCTestCase {
    func testCardUsesCompactHeightForCurrentReferenceFrame() {
        let item = FrameStripCardItem(
            id: UUID(),
            frameLabel: "#002",
            displayFilename: "shot-001.png",
            isDisplayFilenamePlaceholder: false,
            isCurrent: true,
            isSelected: true,
            isIncludedReference: true,
            isActiveReference: true,
            trackingBadge: FrameStripTrackingBadge(
                state: .reference,
                label: "Ref",
                tint: .green
            )
        )
        let view = makeCardView(item: item)
        let fittingSize = fittingSize(for: view)

        XCTAssertEqual(fittingSize.width, 148, accuracy: 1)
        XCTAssertLessThan(fittingSize.height, 110)
        XCTAssertNotNil(renderedPNGData(for: view, fittingSize: fittingSize))
    }

    func testCardRendersPersistentReferenceActionWithinCompactEnvelope() {
        let item = FrameStripCardItem(
            id: UUID(),
            frameLabel: "#003",
            displayFilename: "shot-003.png",
            isDisplayFilenamePlaceholder: false,
            isCurrent: false,
            isSelected: false,
            isIncludedReference: false,
            isActiveReference: false,
            showsPersistentReferenceAction: true,
            trackingBadge: nil
        )
        let view = makeCardView(item: item)
        let fittingSize = fittingSize(for: view)

        XCTAssertEqual(fittingSize.width, 148, accuracy: 1)
        XCTAssertLessThan(fittingSize.height, 110)
        XCTAssertNotNil(renderedPNGData(for: view, fittingSize: fittingSize))
    }

    private func makeCardView(item: FrameStripCardItem) -> FrameStripCardView {
        FrameStripCardView(
            item: item,
            allFrameIDs: [item.id],
            selectedFrameIDs: item.isSelected ? [item.id] : [],
            onSelect: { _ in },
            onAddReference: {},
            onMakeActiveReference: {},
            onRemoveReference: {}
        )
    }

    private func fittingSize(for view: FrameStripCardView) -> CGSize {
        NSHostingView(rootView: view).fittingSize
    }

    private func renderedPNGData(for view: FrameStripCardView, fittingSize: CGSize) -> Data? {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: fittingSize)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return nil
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }
}
