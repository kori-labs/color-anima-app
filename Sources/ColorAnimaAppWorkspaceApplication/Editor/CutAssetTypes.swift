public enum CutAssetKind: String, Codable, CaseIterable, Hashable, Sendable {
    case outline
    case highlightLine
    case shadowLine

    public var storageBasename: String {
        switch self {
        case .outline:
            "outline"
        case .highlightLine:
            "highlight-line"
        case .shadowLine:
            "shadow-line"
        }
    }
}

public struct CutAssetRef: Codable, Hashable, Equatable, Sendable {
    public var kind: CutAssetKind
    public var relativePath: String
    public var originalFilename: String?

    public init(kind: CutAssetKind, relativePath: String, originalFilename: String? = nil) {
        self.kind = kind
        self.relativePath = relativePath
        self.originalFilename = originalFilename
    }
}

public struct CutAssetCatalog: Codable, Hashable, Equatable, Sendable {
    public var outline: CutAssetRef?
    public var highlightLine: CutAssetRef?
    public var shadowLine: CutAssetRef?

    public init(
        outline: CutAssetRef? = nil,
        highlightLine: CutAssetRef? = nil,
        shadowLine: CutAssetRef? = nil
    ) {
        self.outline = outline
        self.highlightLine = highlightLine
        self.shadowLine = shadowLine
    }

    public subscript(kind: CutAssetKind) -> CutAssetRef? {
        get {
            switch kind {
            case .outline:
                outline
            case .highlightLine:
                highlightLine
            case .shadowLine:
                shadowLine
            }
        }
        set {
            switch kind {
            case .outline:
                outline = newValue
            case .highlightLine:
                highlightLine = newValue
            case .shadowLine:
                shadowLine = newValue
            }
        }
    }
}
