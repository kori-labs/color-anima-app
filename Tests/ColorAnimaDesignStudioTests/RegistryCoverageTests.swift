import Testing
@testable import ColorAnimaDesignStudioPreview

/// Asserts that every ID listed in `expectedPrimitiveIDs` is present in
/// `ComponentPreviewRegistry.entries`. This test fails fast if a new primitive
/// is added to the design system without a corresponding registry entry.
@MainActor
@Suite("Registry Coverage")
struct RegistryCoverageTests {
    @Test("All expected primitive IDs are enrolled in ComponentPreviewRegistry")
    func allPrimitiveIDsEnrolled() {
        let enrolledIDs = Set(ComponentPreviewRegistry.entries.map(\.id))
        for expectedID in expectedPrimitiveIDs {
            #expect(enrolledIDs.contains(expectedID), "Missing registry entry for id: \(expectedID)")
        }
    }

    @Test("ComponentPreviewRegistry has no duplicate IDs")
    func noDuplicateIDs() {
        let allIDs = ComponentPreviewRegistry.entries.map(\.id)
        let uniqueIDs = Set(allIDs)
        #expect(allIDs.count == uniqueIDs.count, "Registry contains duplicate entry IDs")
    }
}
