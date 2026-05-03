import Foundation

public struct LayerVisibility: Codable, Hashable, Equatable, Sendable {
    public var showOutline: Bool
    public var showBaseOverlay: Bool
    public var showHighlightLine: Bool
    public var showShadowLine: Bool

    public init(
        showOutline: Bool = true,
        showBaseOverlay: Bool = true,
        showHighlightLine: Bool = true,
        showShadowLine: Bool = true
    ) {
        self.showOutline = showOutline
        self.showBaseOverlay = showBaseOverlay
        self.showHighlightLine = showHighlightLine
        self.showShadowLine = showShadowLine
    }
}
