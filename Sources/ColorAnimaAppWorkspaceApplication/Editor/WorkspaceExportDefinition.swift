import Foundation

public struct WorkspaceExportDefinition: Hashable, Sendable {
    public let title: String
    public let suggestedFilename: String
    public let includesReviewAnnotations: Bool

    public static let visiblePreview = WorkspaceExportDefinition(
        title: "Export Composite Preview",
        suggestedFilename: "color-anima-preview",
        includesReviewAnnotations: false
    )

    public static let reviewPreview = WorkspaceExportDefinition(
        title: "Export Review PNG",
        suggestedFilename: "color-anima-preview-review",
        includesReviewAnnotations: true
    )

    public init(title: String, suggestedFilename: String, includesReviewAnnotations: Bool) {
        self.title = title
        self.suggestedFilename = suggestedFilename
        self.includesReviewAnnotations = includesReviewAnnotations
    }
}
