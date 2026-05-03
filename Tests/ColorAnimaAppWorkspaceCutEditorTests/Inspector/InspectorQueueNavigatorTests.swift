import AppKit
import ColorAnimaAppWorkspaceApplication
import SwiftUI
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

@MainActor
final class InspectorQueueNavigatorTests: XCTestCase {
    func testInspectorQueueNavigatorRendersCurrentItemSummary() {
        let state = TrackingQueueNavigatorPresentation(
            frameID: UUID(),
            regionID: UUID(),
            currentIndex: 1,
            totalCount: 3,
            currentItem: TrackingQueueNavigatorItem(
                frameID: UUID(),
                regionID: UUID(),
                regionDisplayName: "Face",
                frameOrderIndex: 1,
                confidenceValue: 0.63,
                reasonCodes: [.lowMargin, .merge],
                isManualOverride: true
            ),
            items: [],
            severity: .reviewNeeded,
            canGoBackward: true,
            canGoForward: true,
            canAccept: true,
            canReassign: true,
            canSkip: true
        )
        let host = NSHostingView(
            rootView: InspectorQueueNavigator(
                state: state,
                onNavigateToQueueItem: { _ in },
                onAccept: { _ in },
                onReassign: { _ in },
                onSkip: { _ in }
            )
        )

        let fittingSize = host.fittingSize

        XCTAssertGreaterThan(fittingSize.width, 0)
        XCTAssertGreaterThan(fittingSize.height, 0)

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
            XCTFail("Expected queue navigator to render into a bitmap")
            return
        }

        host.cacheDisplay(in: host.bounds, to: bitmap)
        XCTAssertNotNil(bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]))
    }
}
